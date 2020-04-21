require "open3"
require "yaml"

# Class to represent ansible inventory
class AnsibleInventory
  attr_accessor :addnsible_inventory_path
  @config = nil
  @path = ""

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
    cmd = "#{ansible_inventory_path} --inventory '#{@path}' --yaml --list"
    o, e, s = run_command(cmd)
    unless s.success?
      warn e
      raise "failed to run `#{cmd}`: #{s}"
    end
    @config = YAML.safe_load(o)
  end

  def run_command(cmd)
    Open3.capture3(cmd)
  end

  # Resolve all hosts in a group
  # @param group [String] name of group
  # @return [Array] array of string of hosts in the group
  def all_hosts_in(group)
    cmd = "#{ansible_path} --inventory '#{@path}' --list-hosts '#{group}'"
    o, e, s = run_command(cmd)
    unless s.success?
      warn e
      raise "failed to run `#{cmd}`: #{s}"
    end
    parse_list_hosts_output(o)
  end

  def parse_list_hosts_output(out)
    result = out.split(/\n/)
    result.shift # remove the first line
    result.map { |i| i.gsub(/\s+/, "").tr("_", ".") }
  end

  def host(host)
    cmd = format(
      "%s --inventory '%s' --yaml --host '%s'",
      ansible_inventory_path, @path, host
    )
    o, e, s = run_command(cmd)
    unless s.success?
      warn e
      raise "failed to run `#{cmd}`: #{s}"
    end
    YAML.safe_load(o)
  end

  def all_groups
    groups = config["all"]["children"].keys
    hidden_groups = []
    groups.each do |group|
      hidden_groups += find_hidden_groups(config["all"]["children"][group])
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
end
