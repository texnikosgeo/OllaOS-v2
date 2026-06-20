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

# requirement ollama app for linux
# this app runs Linux command: ollama rm and returns the output
# this app is part of OllaOS System
puts "type model name to remove :"
user_answer = gets.chomp
command = `ollama rm #{user_answer}`
puts command
puts "Press Enter to continue..."
continue = gets.chomp
