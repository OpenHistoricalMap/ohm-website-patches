#!/usr/bin/env ruby
# Generate overrides/<locale>.yml from ohm-website translations, keeping only
# the keys from overrides/en.yml that differ from upstream (UPSTREAM_BASE).
#
# Usage: ruby scripts/extract-locale-overrides.rb /path/to/ohm-website

require "yaml"

PATCHES_ROOT = File.expand_path("..", __dir__)
OHM_WEBSITE = ARGV[0] or abort "usage: #{$0} /path/to/ohm-website"
UPSTREAM_BASE = File.read(File.join(PATCHES_ROOT, "UPSTREAM_BASE")).strip
OVERRIDES_DIR = File.join(PATCHES_ROOT, "overlays/config/locales/overrides")

def flatten_keys(hash, prefix = [])
  hash.flat_map do |k, v|
    path = prefix + [k.to_s]
    v.is_a?(Hash) ? flatten_keys(v, path) : [path]
  end
end

def dig_path(hash, path)
  path.reduce(hash) do |node, key|
    return nil unless node.is_a?(Hash)
    node[key] || node[key.to_sym] || (node.keys.find { |nk| nk.to_s == key }&.then { |nk| node[nk] })
  end
end

def bury(hash, path, value)
  *parents, leaf = path
  node = parents.reduce(hash) { |n, key| n[key] ||= {} }
  node[leaf] = value
end

ohm_keys = flatten_keys(YAML.load_file(File.join(OVERRIDES_DIR, "en.yml"))["en"])
puts "OHM override keys: #{ohm_keys.size}"

stats = []
Dir[File.join(OHM_WEBSITE, "config/locales/*.yml")].sort.each do |file|
  basename = File.basename(file)
  next if basename == "en.yml"

  code = File.basename(basename, ".yml")
  ohm_root = YAML.unsafe_load_file(file)
  ohm_data = ohm_root.values.first or next

  upstream_raw = `git -C #{OHM_WEBSITE} show #{UPSTREAM_BASE}:config/locales/#{basename} 2>/dev/null`
  upstream_data = upstream_raw.empty? ? {} : (YAML.unsafe_load(upstream_raw)&.values&.first || {})

  out = {}
  ohm_keys.each do |path|
    ohm_value = dig_path(ohm_data, path)
    next if ohm_value.nil?
    next if ohm_value == dig_path(upstream_data, path)
    bury(out, path, ohm_value)
  end

  next if out.empty?

  source_header = File.foreach(file).take_while { |l| l.start_with?("#") }
                      .reject { |l| l.include?("Export driver") }.join
  header = source_header + "# Do not edit by hand.\n"
  yaml = { code => out }.to_yaml(line_width: -1).sub(/\A---\n/, "")
  File.write(File.join(OVERRIDES_DIR, basename), header + yaml)
  stats << [code, flatten_keys(out).size]
end

puts "wrote #{stats.size} locale files:"
stats.sort_by { |_, n| -n }.each { |code, n| puts format("  %-12s %4d keys", code, n) }
