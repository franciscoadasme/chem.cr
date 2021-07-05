require "../../spec_helper"

describe Chem::PDB::Hybrid36 do
  describe ".decode" do
    it "decodes four-wide string numbers" do
      [
        {"   0", 0},
        {"   1", 1},
        {"  78", 78},
        {" 999", 999},
        {"-999", -999},
        {"5959", 5959},
        {"9999", 9999},
        {"A000", 10_000},
        {"A001", 10_001},
        {"A01Z", 10_071},
        {"A020", 10_072},
        {"AZZZ", 56_655},
        {"ZZZZ", 1_223_055},
        {"azzz", 1_269_711},
        {"zzzz", 2_436_111},
      ].each do |str, num|
        PDB::Hybrid36.decode(str, width: 4).should eq num
      end
    end

    it "decodes five-width string numbers" do
      [
        {"    0", 0},
        {"    1", 1},
        {"   78", 78},
        {"  999", 999},
        {" 5959", 5959},
        {"-5959", -5959},
        {"99999", 99_999},
        {"A0000", 100_000},
        {"A000A", 100_010},
        {"A001Z", 100_071},
        {"A0020", 100_072},
        {"AZZZZ", 1_779_615},
        {"ZZZZZ", 43_770_015},
        {"azzzz", 45_449_631},
        {"zzzzz", 87_440_031},
      ].each do |str, num|
        PDB::Hybrid36.decode(str, width: 5).should eq num
      end
    end

    it "returns zero for blank string" do
      PDB::Hybrid36.decode("    ", width: 4).should eq 0
    end

    it "raises for invalid number literal" do
      ["", " 1234", " abc", "abc-", "40a0"].each do |str|
        expect_raises(ArgumentError, "Invalid number literal") do
          PDB::Hybrid36.decode str, width: 4
        end
      end
    end
  end

  describe ".encode" do
    it "encodes numbers" do
      [
        {-123, "-123"},
        {0, "   0"},
        {12, "  12"},
        {123, " 123"},
        {1234, "1234"},
        {9999, "9999"},
        {10_000, "A000"},
        {10_004, "A004"},
        {56_655, "AZZZ"},
        {56_656, "B000"},
        {1_223_055, "ZZZZ"},
        {1_223_092, "a010"},
        {2_436_111, "zzzz"},
        {3_459_232, "C0000"},
        {45_449_632, "b0000"},
      ].each do |num, str|
        PDB::Hybrid36.encode num, width: str.size
      end
    end

    it "fails for numbers out of range" do
      [-9999, 2_436_112].each do |num|
        expect_raises(ArgumentError, "out of range") do
          PDB::Hybrid36.encode num, width: 4
        end
      end
    end
  end
end
