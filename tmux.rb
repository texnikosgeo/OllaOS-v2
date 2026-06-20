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

# requirement tmux app for linux
# this app launches tmux in a new terminal window
# this app is part of OllaOS System
term = `which x-terminal-emulator 2>/dev/null`.strip
term = `which gnome-terminal 2>/dev/null`.strip if term.empty?
term = `which lxterminal 2>/dev/null`.strip if term.empty?
term = `which xfce4-terminal 2>/dev/null`.strip if term.empty?

if term.empty?
  puts "No terminal emulator found. Install one (e.g. sudo apt install lxterminal)."
else
  pid = Process.spawn(term, '-e', 'tmux', %i[out err] => '/dev/null')
  Process.detach(pid)
  puts "tmux launched in new window (PID #{pid})."
end
