#!/usr/bin/env ruby
# OllaOS v2 — AI-powered Debian assistant with Ollama integration
# Copyright (C) 2026  OllaOS Contributors
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

# OllaOS Dependency Checker
# Checks all required tools, gems, and services needed to run OllaOS.
# Offers one-shot installation of missing packages.
# this app is part of OllaOS System

REQUIRED_BINS = {
  'ruby'     => { pkg: 'ruby',         desc: 'Ruby runtime',           critical: true },
  'fastfetch'=> { pkg: 'fastfetch',     desc: 'System info tool',       critical: false },
  'geany'    => { pkg: 'geany',         desc: 'Text editor',            critical: false },
  'df'       => { pkg: 'coreutils',     desc: 'Disk space (coreutils)', critical: false },
  'ls'       => { pkg: 'coreutils',     desc: 'List files (coreutils)', critical: false },
  'pwd'      => { pkg: 'coreutils',     desc: 'Print directory',        critical: false },
  'top'      => { pkg: 'procps',        desc: 'Process viewer',         critical: false },
  'tmux'     => { pkg: 'tmux',          desc: 'Terminal multiplexer',    critical: false },
  'ddgr'     => { pkg: 'ddgr',          desc: 'Web search (DuckDuckGo)',critical: false },
  'wget'     => { pkg: 'wget',          desc: 'File downloader',        critical: false },
  'lynx'     => { pkg: 'lynx',          desc: 'Web page text extractor',critical: false },
  'curl'     => { pkg: 'curl',          desc: 'HTTP client',            critical: false },
  'sudo'     => { pkg: 'sudo',          desc: 'Privilege escalation',   critical: false },
  'ollama'   => { pkg: nil,             desc: 'AI server (ollama.com)',  critical: true },
}

REQUIRED_GEMS = {
  'sinatra'  => { desc: 'Web framework',        critical: true },
}

SERVICES = {
  'ollama'   => { desc: 'Ollama AI service',    port: 11434, critical: true },
}

def color(text, code)
  "\e[#{code}m#{text}\e[0m"
end

def green(text); color(text, 32); end
def red(text);   color(text, 31); end
def yellow(text);color(text, 33); end
def bold(text);  color(text, 1);  end

def heading(text)
  puts "\n#{bold(text)}"
  puts '=' * 60
end

def check_bins
  heading 'Checking system binaries'
  missing = []

  REQUIRED_BINS.each do |name, info|
    print "  #{info[:desc].ljust(36)} "
    if system("which #{name} > /dev/null 2>&1")
      puts green('FOUND')
    else
      puts red('MISSING')
      missing << name
    end
  end

  missing
end

def check_gems
  heading 'Checking Ruby gems'
  missing = []

  REQUIRED_GEMS.each do |name, info|
    print "  #{info[:desc].ljust(36)} "
    if system("gem list -i #{name} > /dev/null 2>&1")
      puts green('FOUND')
    else
      puts red('MISSING')
      missing << name
    end
  end

  missing
end

def check_services
  heading 'Checking services'
  issues = []

  SERVICES.each do |name, info|
    if info[:port]
      print "  #{info[:desc].ljust(36)} "
      if system("ss -tlnp 2>/dev/null | grep -q ':#{info[:port]} '")
        puts green('RUNNING')
      else
        puts yellow('NOT RUNNING')
        issues << name
      end
    end
  end

  issues
end

def install_missing_bins(missing)
  return if missing.empty?

  apt_pkgs = missing.filter_map { |n| REQUIRED_BINS[n][:pkg] }.uniq

  if apt_pkgs.empty?
    puts "  No apt packages to install."
    return
  end

  puts "\n  #{yellow('The following packages will be installed:')}"
  apt_pkgs.each { |p| puts "    - #{p}" }

  print "\n  Install with apt? [Y/n] "
  answer = $stdin.gets.strip.downcase
  return unless answer.empty? || answer == 'y'

  cmd = 'sudo apt update && sudo apt install -y ' + apt_pkgs.join(' ')
  puts "  Running: #{cmd}"
  system(cmd)
  puts green("\n  Done.")
end

def install_missing_gems(missing)
  return if missing.empty?

  puts "\n  #{yellow('The following gems will be installed:')}"
  missing.each { |g| puts "    - #{g}" }

  print "\n  Install with gem? [Y/n] "
  answer = $stdin.gets.strip.downcase
  return unless answer.empty? || answer == 'y'

  cmd = 'gem install ' + missing.join(' ')
  puts "  Running: #{cmd}"
  system(cmd)
  puts green("\n  Done.")
end

def suggest_ollama_install
  puts "\n  #{yellow('Ollama is not installed or not in PATH.')}"
  puts "  Install from: #{bold('https://ollama.com')}"
  puts "  Or run:"
  puts "    #{yellow('curl -fsSL https://ollama.com/install.sh | sh')}"
end

def suggest_ollama_start
  puts "\n  #{yellow('Ollama is installed but not running.')}"
  puts "  Start it with:"
  puts "    #{yellow('ollama serve &')}"
  puts "  Or enable as a systemd service:"
  puts "    #{yellow('sudo systemctl enable --now ollama')}"
end

# ---- Main ----
puts bold("\n  OllaOS Dependency Checker")
puts '  ' + '=' * 30
puts "  Detected: #{`cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d= -f2 | tr -d '\"'`.strip}"
puts "  Ruby:     #{RUBY_VERSION}"
puts "  Arch:     #{RUBY_PLATFORM}"

missing_bins = check_bins
missing_gems = check_gems
service_issues = check_services

heading 'Summary'
if missing_bins.empty? && missing_gems.empty? && service_issues.empty?
  puts green('  All dependencies satisfied!')
  exit 0
end

unless missing_bins.empty?
  puts yellow("\n  Missing binaries: #{missing_bins.join(', ')}")
end
unless missing_gems.empty?
  puts yellow("  Missing gems:      #{missing_gems.join(', ')}")
end
unless service_issues.empty?
  puts yellow("  Service issues:    #{service_issues.join(', ')}")
end

heading 'Installation'

if missing_bins.any? { |b| REQUIRED_BINS[b][:pkg] }
  install_missing_bins(missing_bins)
end

install_missing_gems(missing_gems)

if missing_bins.include?('ollama')
  suggest_ollama_install
elsif service_issues.include?('ollama')
  suggest_ollama_start
end

puts green("\n  All checks complete. Run 'ruby ol_sin.rb' to start OllaOS.\n")
