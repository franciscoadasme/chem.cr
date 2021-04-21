require "../spec_helper"

describe Assignable do
  it "generates initialize, instance variables and getters" do
    foo = Foo.new 0
    foo.bar.should eq 0
    foo.baz.should be_nil
    foo.active?.should be_true
    foo.gt?(10).should be_false

    foo = Foo.new 101, "none", active: false
    foo.bar.should eq 101
    foo.baz.should eq "none"
    foo.active?.should be_false
    foo.gt?(10).should be_true
  end
end

struct Foo
  include Assignable

  needs bar : Int32
  needs baz : String?
  needs active : Bool = true

  def gt?(value)
    @bar > value
  end
end
