#
# Copyright:: Copyright (c) 2017 Chef Software Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require "chef-workstation/log"
require "chef-workstation/error"
require "train"
module ChefWorkstation
  class TargetHost
    attr_reader :config, :reporter, :backend

    def self.instance_for_url(target, opts = {})
      target_host = new(target, opts)
      target_host.connect!
      target_host
    end

    def initialize(host_url, opts = {}, logger = nil)
      cfg = { target: host_url,
              sudo: opts.has_key?(:root) ? opts[:root] : true,
              www_form_encoded_password: true,
              key_files: opts[:identity_file],
              logger: ChefWorkstation::Log }
      if opts.has_key? :ssl
        cfg[:ssl] = opts[:ssl]
        cfg[:self_signed] = opts[:ssl_verify] == false ? true : false
      end

      @config = Train.target_config(cfg)
      @type = Train.validate_backend(@config)
      @train_connection = Train.create(@type, config)
    end

    def connect!
      if @backend.nil?
        @backend = @train_connection.connection
        @backend.wait_until_ready
      end
      nil
    end

    def hostname
      config[:host]
    end

    def base_os
      if platform.family == "windows"
        :windows
      elsif platform.linux?
        :linux
      else
        raise ChefWorkstation::TargetHost::UnsupportedTargetOS.new(platform.name)
      end
    end

    def platform
      backend.platform
    end

    def run_command!(command)
      result = backend.run_command command
      if result.exit_status != 0
        raise RemoteExecutionFailed.new(@config[:host], command, result)
      end
      result
    end

    def run_command(command)
      backend.run_command command
    end

    def upload_file(local_path, remote_path)
      backend.upload(local_path, remote_path)
    end

    # Returns the installed chef version as a Gem::Version,
    # or raised ChefNotInstalled if chef client version manifest can't
    # be found.
    def installed_chef_version
      return @installed_chef_version if @installed_chef_version
      # Note: In the case of a very old version of chef (that has no manifest - pre 12.0?)
      #       this will report as not installed.
      manifest = get_chef_version_manifest()
      raise ChefNotInstalled.new if manifest == :not_found
      # We'll split the version here because  unstable builds (where we currently
      # install from) are in the form "Major.Minor.Build+HASH" which is not a valid
      # version string.
      @installed_chef_version = Gem::Version.new(manifest["build_version"].split("+")[0])
    end

    MANIFEST_PATHS = {
      # TODO - use a proper method to query the win installation path -
      #        currently we're assuming the default, but this can be customized
      #        at install time.
      windows: "c:\\opscode\\chef\\version-manifest.json",
      linux: "/opt/chef/version-manifest.json"
    }

    def get_chef_version_manifest
      path = MANIFEST_PATHS[base_os()]
      content = backend.file(path).content
      if content
        JSON.parse(content)
      else
        :not_found
      end
    end

    class RemoteExecutionFailed < ChefWorkstation::ErrorNoLogs
      attr_reader :stdout, :stderr
      def initialize(host, command, result)
        super("CHEFRMT001",
              command,
              result.exit_status,
              host,
              result.stderr.empty? ? result.stdout : result.stderr)
      end
    end

    class ChefNotInstalled < StandardError; end

    class UnsupportedTargetOS < ChefWorkstation::Error
      def initialize(os_name); super("CHEFTARG001", os_name); end
    end
  end
end
