RSpec.describe AnsibleInventory do
  let(:inventory) { AnsibleInventory.new("foo/bar") }
  let(:inventory_simple) { YAML.load_file("spec/fixtures/simple.yml") }
  let(:inventory_simple_host) { YAML.load_file("spec/fixtures/simple_host.yml") }

  it "has a version number" do
    expect(AnsibleInventory.VERSION).not_to be nil
  end

  describe ".new" do
    it "raises no error" do
      expect{ AnsibleInventory.new("/foo/bar") }.not_to raise_error
    end
  end

  describe "#ansible_inventory_path" do
    it "is ansible-inventory" do
      expect(inventory.ansible_inventory_path).to eq "ansible-inventory"
    end
  end

  describe "#ansible_path" do
    it "is ansible" do
      expect(inventory.ansible_path).to eq "ansible"
    end
  end

  describe "#all_groups" do
    context "inventory is simple" do

      it "returns array" do
        allow(inventory).to receive(:config).and_return(inventory_simple)
        expect(inventory.all_groups).to eq %w[mx ungrouped virtualbox virtualbox-credentials virtualbox-mx]
      end
    end
  end

  describe "#all_hosts_in" do
    context "inventory is simple" do
      before do
        allow(inventory).to receive(:config).and_return(inventory_simple)
      end
      context "given a group that exists" do
        it "returns mx1" do
          expect(inventory.all_hosts_in("mx")).to eq ["mx1.trombik.org"]
        end

        it "returns mx1" do
          expect(inventory.all_hosts_in("virtualbox")).to eq ["mx1.trombik.org"]
        end

        it "returns mx1" do
          expect(inventory.all_hosts_in("virtualbox-mx")).to eq ["mx1.trombik.org"]
        end
      end

      context "given a group that does not exist" do
        it "returns empty array" do
          expect(inventory.all_hosts_in("foo")).to eq []
        end
      end
      context "given invalid arg" do
        it "returns empty array" do
          expect(inventory.all_hosts_in(nil)).to eq []
          expect(inventory.all_hosts_in(false)).to eq []
          expect(inventory.all_hosts_in([])).to eq []
          expect(inventory.all_hosts_in({})).to eq []
        end
      end
    end
    context "inventory is invalid" do
      before do
        allow(inventory).to receive(:config).and_return([])
      end

      it "raise exception" do
        expect{ inventory.all_hosts_in("foo") }.to raise_error(RuntimeError)
      end
    end
  end

  describe "#host" do
    context "inventory is simple_host" do
      before do
        allow(inventory).to receive(:config_host).with("mx1.trombik.org").and_return(inventory_simple_host)
      end

      it "returns mx1.trombik.org" do
        expect(inventory.host("mx1.trombik.org")).to include("ansible_host" => "172.16.100.100", "vagrant_priority" => 10)
      end
    end
  end
end
