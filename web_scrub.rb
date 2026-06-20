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

# requirement lynx app for linux and internet connection active is needed.
# this app runs Linux command: lynx + url and returns the page text
# this app is part of OllaOS System
puts "Website URL :"
url = gets.chomp
command = `lynx -width=400 -dump -nolist -nopause "#{url}"`
puts command
puts "Press Enter to continue..."
continue = gets.chomp
