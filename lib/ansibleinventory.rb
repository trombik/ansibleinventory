# frozen_string_literal: true

require "open3"
require "yaml"
require "shellwords"

# Class to represent ansible inventory
class AnsibleInventory
  attr_accessor :addnsible_inventory_path
  @config = {}
  @config_list_hosts = nil
  @path = ""
  @config_host = {}

  def self.version
    "0.1.0"
  end

  def initialize(path)
    @path = path
  end

  def ansible_inventory_path
    "ansible-inventory"
  end

  def ansible_path
    "ansible"
  end

  # Returns parsed inventory content
  def config
    return @config if @config

    cmd = "#{ansible_inventory_path}" \
          " --inventory #{Shellwords.escape(@path)}" \
          " --yaml --list"
    o, e, s = run_command(cmd)
    unless s.success?
      warn e
      raise "failed to run `#{cmd}`: #{s}"
    end
    @config = YAML.safe_load(o)
  end

  def config_host(host)
    return @config_host[host] if !@config_host.nil? && @config_host.key?(host)

    cmd = "#{ansible_inventory_path}" \
          " --inventory #{Shellwords.escape(@path)}" \
          " --yaml --host #{Shellwords.escape(host)}"
    o, e, s = run_command(cmd)
    unless s.success?
      warn e
      raise "failed to run `#{cmd}`: #{s}"
    end
    @config[host] = YAML.safe_load(o)
  end

  def config_list_hosts(group)
    return @config_list_hosts if @config_list_hosts

    cmd = "#{ansible_path}" \
          " --inventory #{Shellwords.escape(@path)}" \
          " --list-hosts #{Shellwords.escape(group)}"
    o, e, s = run_command(cmd)
    unless s.success?
      warn e
      raise "failed to run `#{cmd}`: #{s}"
    end
    @config_list_hosts = o
  end

  def run_command(cmd)
    Open3.capture3(cmd)
  end

  # Resolve all hosts in a group
  # @param group [String] name of group
  # @return [Array] array of string of hosts in the group
  def all_hosts_in(group)
    resolve_hosts_of(root_of_groups[group])
  end

  def host(host)
    config_host(host)
  end

  def root_of_groups
    c = config
    begin
      c["all"]["children"]
    rescue StandardError
      raise "BUG: unexpected inventory result from ansible-inventory"
    end
  end

  def all_groups
    groups = root_of_groups.keys
    hidden_groups = []
    groups.each do |group|
      hidden_groups += find_hidden_groups(root_of_groups[group])
    end
    (groups + hidden_groups).uniq
  end

  def find_hidden_groups(parent)
    return [] if !parent ||
                 !parent.key?("children") ||
                 !parent["children"].respond_to?("keys")

    found = parent["children"].keys
    found.each do |child|
      found += find_hidden_groups(parent["children"][child])
    end
    found.uniq
  end

  def find_host_by_ec2_hostname(hostname)
    config["all"]["children"]["ec2"]["hosts"][hostname.gsub(/[.]/, "_")]
  end

  def resolve_hosts_of(group)
    hosts = []
    return [] if group.nil? || group.empty?

    if group.key?("children")
      group["children"].each_key do |child|
        hosts += resolve_hosts_of(group["children"][child])
      end
    elsif group.key?("hosts")
      hosts += group["hosts"].keys.map { |key| key.gsub("_", ".") }
    else
      raise "BUG \n" + group.to_yaml
    end
    hosts
  end
end
