require "benchmark"
require "../src/chem"

# Reports the best time (ms) of running the given block. The execution
# is repeated *repeats* times such that the lowest time is returned to
# avoid potential slow downs by external processes.
def bench(label : String, repeats : Int = 10_000, & : ->) : Nil
  {% if !flag?(:release) %}
    puts "Warning: benchmarking without the `--release` flag won't yield useful results"
  {% end %}
  best_time = (0...repeats).min_of do
    Time.measure do
      yield
    end
  end
  puts "#{label} took #{best_time.total_milliseconds} ms"
end

# Returns the path to the given data bench file.
def data_file(filename : String) : String
  path = File.join(__DIR__, "data", filename)
  raise IO::Error.new("File not found: #{filename}") unless File.exists?(path)
  path
end
