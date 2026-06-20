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

require 'sinatra'
require 'json'
require 'net/http'
require 'uri'
require 'open3'

OLLAMA_HOST = ENV['OLLAMA_HOST'] || 'http://localhost:11434'

STYLE = '<style>
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body { font-family: system-ui, sans-serif; max-width: 800px; margin: 0 auto; padding: 20px; background: #1a1a2e; color: #eee; }
  h1 { margin-bottom: 10px; }
  pre { background: #16213e; padding: 15px; border-radius: 8px; overflow-x: auto; border: 1px solid #333; margin: 10px 0; }
  form { margin: 15px 0; display: flex; gap: 10px; flex-wrap: wrap; align-items: center; }
  label { font-size: 14px; }
  input[type="text"] { padding: 10px; border-radius: 8px; border: 1px solid #333; background: #16213e; color: #eee; font-size: 14px; flex: 1; min-width: 200px; }
  input[type="submit"], .btn { padding: 10px 20px; border-radius: 8px; border: none; background: #e94560; color: white; cursor: pointer; font-size: 14px; text-decoration: none; display: inline-block; }
  input[type="submit"]:hover, .btn:hover { background: #c73650; }
  .nav { display: flex; gap: 10px; flex-wrap: wrap; margin-top: 20px; }
  .nav .btn { font-size: 13px; padding: 8px 14px; }
  .btn-danger { background: #555; }
  .btn-danger:hover { background: #e94560; }
  p { margin: 10px 0; }
</style>'

SCRIPT_DIR = __dir__
CACHE_LOG = File.join(SCRIPT_DIR, 'OllaOS.Cache.txt')

File.open(CACHE_LOG, 'w') do |f|
  f.puts("=== OllaOS Cache Log ===")
  f.puts("Session started: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}")
  f.puts("")
end

TOOLBAR = <<~HTML.strip
  <div class="toolbar">
    <a href="/ol_list" class="btn">List Models</a>
    <a href="/ol_pull" class="btn">Pull Model</a>
    <a href="/ol_rm" class="btn">Remove Model</a>
    <a href="/ol_run" class="btn">Chat</a>
    <a href="/" class="btn">Home</a>
    <a href="#" class="btn btn-danger" onclick="restartServer();return false;">Restart</a>
    <a href="#" class="btn btn-danger" onclick="stopServer();return false;">Stop</a>
  </div>
HTML

def cache_append(type, content)
  entry = "[#{Time.now.strftime('%Y-%m-%d %H:%M:%S')}] [#{type}]\n#{content.strip}\n\n"
  File.open(CACHE_LOG, 'a') { |f| f.write(entry) }
end

def cache_read
  File.exist?(CACHE_LOG) ? File.read(CACHE_LOG) : ''
end

TOOLS = {
  'df'        => { desc: 'disk space usage', file: 'df.rb', args: {}, match: [/disk|space|storage|df/i] },
  'ls'        => { desc: 'list directory files', file: 'ls.rb', args: {}, match: [/list.*file|directory|contents|what.*(here|in)/i] },
  'pwd'       => { desc: 'current directory path', file: 'pwd.rb', args: {}, match: [/current.*(dir|folder|path)|where.*(am|are)/i] },
  'top'       => { desc: 'running processes', file: 'top.rb', args: {}, match: [/process|running|top/i] },
  'fastfetch' => { desc: 'system hardware info', file: 'fastfetch.rb', args: {}, match: [/system.*info|fastfetch|hardware|cpu|memory|specs|system.*review/i] },
  'wget'      => { desc: 'download a file from a URL', file: 'wget.rb', args: { url: 'URL' }, match: [/download.*file|wget/i] },
  'geany'     => { desc: 'launch the Geany text editor', file: 'geany.rb', args: {}, match: [/geany|text.*editor|editor/i] },
  'up_deb'    => { desc: 'update all system packages', file: 'up_deb.rb', args: {}, match: [/update|upgrade.*(system|package)|apt/i] },
  'lookup'    => { desc: 'look up information on the web', file: 'web_search.rb', args: { q: 'query' }, match: [/look\s*up|search|find.*(info|about)|what.*is|tell.*(about|me)/i] },
  'scrub'     => { desc: 'extract text from a webpage', file: 'web_scrub.rb', args: { url: 'URL' }, match: [/scrub|extract.*(text|content|page)|fetch.*url/i] },
  'ol_list'   => { desc: 'list downloaded Ollama models', file: 'ol_list.rb', args: {}, match: [/list.*(ollama|model|download)/i] },
  'ol_pull'   => { desc: 'download an Ollama model', file: 'ol_pull.rb', args: { model: 'model name' }, match: [/pull|download.*model|install.*(ollama|model)/i] },
  'ol_rm'     => { desc: 'delete an Ollama model', file: 'ol_rm.rb', args: { model: 'model name' }, match: [/remove|delete|rm.*model/i] },
  'tmux'      => { desc: 'launch tmux in a new terminal window', file: 'tmux.rb', args: {}, match: [/tmux|terminal.*(session|multiplexer)|session.*manager/i] },
}

SYSTEM_PROMPT = "You are OllaOS on Debian Linux. Read the conversation log and respond to the user's latest request. Be concise."

def call_ollama(model, messages)
  uri = URI("#{OLLAMA_HOST}/api/chat")
  http = Net::HTTP.new(uri.host, uri.port)
  http.open_timeout = 30
  http.read_timeout = 900
  req = Net::HTTP::Post.new(uri)
  req['Content-Type'] = 'application/json'
  req.body = { model: model, messages: messages, stream: false }.to_json
  res = http.request(req)
  JSON.parse(res.body)
rescue Errno::ECONNREFUSED
  { 'error' => "Cannot connect to Ollama" }
rescue => e
  { 'error' => e.message }
end

def run_script(file, stdin_input = '')
  script_path = File.join(SCRIPT_DIR, file)
  stdout, stderr, status = Open3.capture3('ruby', script_path, stdin_data: stdin_input)
  output = stdout + stderr
  output.sub(/\n?Press Enter to continue\.\.\.\n?\z/, '').strip.gsub(/\e\[\d+(?:;\d+)*m/, '')[0..2000]
rescue => e
  "Error: #{e.message}"
end

def detect_tool(text)
  TOOLS.each { |name, t| t[:match]&.each { |p| return name if text.match?(p) } }
  nil
end

def extract_args(text, tool_name)
  tool = TOOLS[tool_name]
  return {} unless tool && tool[:args].any?
  args = {}
  tool[:args].each_key do |key|
    case key.to_s
    when 'q'
      m = text.match(/(?:look\s*up|search|find|for|about|regarding|tell me about)\s+(.+)/i)
      args['q'] = m ? m[1].strip : text
    when 'url'
      m = text.match(%r{https?://\S+})
      args['url'] = m ? m[0] : text
    when 'model'
      m = text.match(/(?:model|pull|download)\s+(\S+)/i)
      args['model'] = m ? m[1] : text.split.last
    end
  end
  args
end

def execute_tool(name, args)
  tool = TOOLS[name]
  return "Error: unknown tool '#{name}'" unless tool
  input = ''
  if tool[:args].any?
    tool[:args].each_key { |k| input += "#{args[k.to_s] || args[k]}\n" }
  end
  input += "\n"
  run_script(tool[:file], input)
end

# === Routes ===

get '/ol_list' do
  result = run_script('ol_list.rb', "\n")
  cache_append('ACTION', "Listed Ollama models\n#{result}")
  content_type :html
  <<-HTML
    <!DOCTYPE html>
    <html>
    <head><title>OllaOS - Models</title>#{STYLE}</head>
    <body>
      #{TOOLBAR}
      <h1>Ollama Models</h1>
      <pre>#{result}</pre>
    </body>
    </html>
  HTML
end

get '/ol_pull' do
  model_name = params['model']
  content_type :html
  if model_name
    result = run_script('ol_pull.rb', "#{model_name}\n\n")
    cache_append('PULL', "Pulled model: #{model_name}\n#{result}")
    <<-HTML
      <!DOCTYPE html>
      <html>
      <head><title>OllaOS - Pull Model</title>#{STYLE}</head>
      <body>
        #{TOOLBAR}
        <h1>Model Downloaded</h1>
        <pre>#{result}</pre>
      </body>
      </html>
    HTML
  else
    <<-HTML
      <!DOCTYPE html>
      <html>
      <head><title>OllaOS - Pull Model</title>#{STYLE}</head>
      <body>
        #{TOOLBAR}
        <h1>Pull Ollama Model</h1>
        <form method="get" action="/ol_pull">
          <label>Model name: <input type="text" name="model" /></label>
          <input type="submit" value="Pull" />
        </form>
      </body>
      </html>
    HTML
  end
end

get '/ol_rm' do
  model_name = params['model']
  content_type :html
  if model_name
    result = run_script('ol_rm.rb', "#{model_name}\n\n")
    cache_append('REMOVE', "Removed model: #{model_name}\n#{result}")
    <<-HTML
      <!DOCTYPE html>
      <html>
      <head><title>OllaOS - Remove Model</title>#{STYLE}</head>
      <body>
        #{TOOLBAR}
        <h1>Model Removed</h1>
        <pre>#{result}</pre>
      </body>
      </html>
    HTML
  else
    <<-HTML
      <!DOCTYPE html>
      <html>
      <head><title>OllaOS - Remove Model</title>#{STYLE}</head>
      <body>
        #{TOOLBAR}
        <h1>Remove Ollama Model</h1>
        <form method="get" action="/ol_rm">
          <label>Model name: <input type="text" name="model" /></label>
          <input type="submit" value="Remove" />
        </form>
      </body>
      </html>
    HTML
  end
end

get '/ol_run' do
  uri = URI("#{OLLAMA_HOST}/api/tags")
  models = JSON.parse(Net::HTTP.get(uri))['models'].map { |m| m['name'] } rescue []
  content_type :html
  <<-HTML
    <!DOCTYPE html>
    <html>
    <head>
      <title>OllaOS Chat</title>
      #{STYLE}
      <style>
        body { font-family: system-ui, sans-serif; max-width: 800px; margin: 0 auto; padding: 20px; background: #1a1a2e; color: #eee; }
        h1 { margin-bottom: 10px; }
        .toolbar { display: flex; gap: 6px; flex-wrap: wrap; margin: 10px 0; }
        .toolbar .btn { font-size: 12px; padding: 6px 12px; }
        .bar { display: flex; gap: 8px; align-items: center; margin: 10px 0; }
        select { padding: 6px 10px; border-radius: 4px; border: 1px solid #333; background: #16213e; color: #eee; flex: 1; }
        #chat { height: 45vh; overflow-y: auto; border: 1px solid #333; padding: 10px; border-radius: 8px; background: #16213e; display: flex; flex-direction: column; gap: 8px; }
        .msg { padding: 10px 14px; border-radius: 12px; max-width: 85%; line-height: 1.5; white-space: pre-wrap; word-wrap: break-word; }
        .user { background: #0f3460; align-self: flex-end; }
        .assistant { background: #1a1a40; align-self: flex-start; }
        .form { display: flex; gap: 8px; margin-top: 10px; }
        #message { flex: 1; padding: 10px; border-radius: 8px; border: 1px solid #333; background: #16213e; color: #eee; font-size: 14px; }
        button, #send-btn, #stop-btn { padding: 10px 20px; border-radius: 8px; border: none; background: #e94560; color: white; cursor: pointer; font-size: 14px; }
        button:hover, #send-btn:hover, #stop-btn:hover { background: #c73650; }
        button:disabled, #send-btn:disabled { opacity: 0.5; cursor: not-allowed; }
        #stop-btn { display: none; }
        .loading { text-align: center; padding: 14px; color: #888; display: flex; align-items: center; justify-content: center; gap: 10px; }
        .spinner { width: 16px; height: 16px; border: 2px solid #555; border-top-color: #e94560; border-radius: 50%; animation: spin 0.8s linear infinite; }
        @keyframes spin { to { transform: rotate(360deg); } }
      </style>
    </head>
    <body>
      <h1>OllaOS Chat</h1>
      #{TOOLBAR}
      <div style="margin:6px 0;display:flex;gap:6px;flex-wrap:wrap;">
        <button onclick="clearCache()">Clear Cache</button>
      </div>
      <div class="bar">
        <label>Model:</label>
        <select id="model">
          #{models.empty? ? '<option>No models found</option>' : models.map { |m| "<option>#{m}</option>" }.join("\n          ")}
        </select>
      </div>
      <div style="display:flex;gap:6px;flex-wrap:wrap;margin-bottom:10px;font-size:12px;">
        <span style="color:#888;">Try:</span>
        <span class="ex" onclick="setMsg('check disk space')">check disk space</span>
        <span class="ex" onclick="setMsg('what are my system specs')">system specs</span>
        <span class="ex" onclick="setMsg('look up ruby on rails')">look up something</span>
        <span class="ex" onclick="setMsg('list my models')">list models</span>
        <span class="ex" onclick="setMsg('what files are here')">what files</span>
        <span class="ex" onclick="setMsg('open tmux')">open tmux</span>
      </div>
      <style>
        .ex { color:#e94560;cursor:pointer;padding:2px 6px;border-radius:4px;background:#16213e; }
        .ex:hover { background:#0f3460; }
      </style>
      <div id="chat"></div>
      <div class="form">
          <input type="text" id="message" placeholder="Ask me anything..." autofocus />
          <button id="send-btn" onclick="send()">Send</button>
          <button id="stop-btn" onclick="stop()">Stop</button>
      </div>
        <script>
          const chat = document.getElementById('chat');
          const model = document.getElementById('model');
          const input = document.getElementById('message');
          const sendBtn = document.getElementById('send-btn');
          const stopBtn = document.getElementById('stop-btn');
          let controller = null;

          function addMsg(role, content) {
            const div = document.createElement('div');
            div.className = 'msg ' + role;
            div.textContent = content;
            chat.appendChild(div);
            chat.scrollTop = chat.scrollHeight;
            return div;
          }

          function setMsg(text) { input.value = text; input.focus(); }
          async function clearCache() {
            await fetch('/api/clear', { method: 'POST' });
            chat.innerHTML = '';
          }
          async function restartServer() {
            if (!confirm('Restart the server? The page will reload.')) return;
            try { await fetch('/api/restart', { method: 'POST' }); } catch(e) {}
            setTimeout(function(){ location.reload(); }, 2000);
          }
          async function stopServer() {
            if (!confirm('Stop the server?')) return;
            try { await fetch('/api/shutdown', { method: 'POST' }); } catch(e) {}
            document.body.innerHTML = '<h1>Server stopped</h1><p>You can close this tab.</p>';
          }

          function stop() {
            if (controller) { controller.abort(); controller = null; }
            const el = document.querySelector('.loading');
            if (el) el.remove();
            stopBtn.style.display = 'none';
            sendBtn.disabled = false;
            input.disabled = false;
            addMsg('assistant', '[Stopped]');
          }

          async function send() {
            const text = input.value.trim();
            if (!text) return;
            input.value = '';
            sendBtn.disabled = true;
            input.disabled = true;
            addMsg('user', text);

            controller = new AbortController();
            stopBtn.style.display = 'inline-block';

            const load = document.createElement('div');
            load.className = 'loading';
            load.innerHTML = '<div class="spinner"></div> Thinking...';
            chat.appendChild(load);

            try {
              const res = await fetch('/api/chat', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ model: model.value, stream: true, messages: [{ role: 'user', content: text }] }),
                signal: controller.signal
              });

              const el = document.querySelector('.loading');
              if (el) el.remove();
              const replyDiv = addMsg('assistant', '');

              if (res.headers.get('Content-Type')?.includes('event-stream')) {
                let full = '';
                const reader = res.body.getReader();
                const decoder = new TextDecoder();
                let buf = '';
                while (true) {
                  const { done, value } = await reader.read();
                  if (done) break;
                  buf += decoder.decode(value, { stream: true });
                  const lines = buf.split('\\n');
                  buf = lines.pop() || '';
                  for (const line of lines) {
                    if (line.startsWith('data: ')) {
                      const data = line.slice(6);
                      if (data === '"__DONE__"') continue;
                      try {
                        const token = JSON.parse(data);
                        full += token;
                        replyDiv.textContent = full;
                        chat.scrollTop = chat.scrollHeight;
                      } catch(e) {}
                    }
                  }
                }
              } else {
                const data = await res.json();
                replyDiv.textContent = data.message?.content || data.error || 'No response';
              }
            } catch(e) {
              const el = document.querySelector('.loading');
              if (el) el.remove();
              if (e.name === 'AbortError') return;
              addMsg('assistant', 'Error: ' + e.message);
            }

            controller = null;
            stopBtn.style.display = 'none';
            sendBtn.disabled = false;
            input.disabled = false;
          }
          input.addEventListener('keydown', function(e) {
            if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); send(); }
          });
        </script>
    </body>
    </html>
  HTML
end

# === Chat API ===
post '/api/chat' do
  begin
    req = JSON.parse(request.body.read)
  rescue JSON::ParserError
    halt 400, { error: 'Invalid JSON' }.to_json
  end

  model_name = req['model']
  stream_mode = req['stream'] == true
  user_text = req['messages'].to_a.reverse.find { |m| m['role'] == 'user' }&.dig('content') || ''

  # 1. Save user input to cache
  cache_append('USER', user_text)

  # 2. Detect and run tool
  tool_name = detect_tool(user_text)
  if tool_name
    args = extract_args(user_text, tool_name)
    result = execute_tool(tool_name, args)
    cache_append("TOOL #{tool_name}", result)
  end

  # 3. Build model messages from cache
  cache_content = cache_read
  ollama_messages = [
    { role: 'system', content: SYSTEM_PROMPT },
    { role: 'user', content: "Conversation log:\n#{cache_content}\n\nRespond to the user's latest request." }
  ]

  unless stream_mode
    response = call_ollama(model_name, ollama_messages)
    if response['error']
      content_type :json
      return { error: response['error'] }.to_json
    end
    reply = response.dig('message', 'content') || ''
    cache_append('MODEL', reply)
    content_type :json
    return { message: { content: reply } }.to_json
  end

  # 4. Streaming response
  content_type 'text/event-stream'
  headers 'Cache-Control' => 'no-cache'
  headers 'Connection' => 'keep-alive'

  stream(:keep_open) do |out|
    uri = URI("#{OLLAMA_HOST}/api/chat")
    http = Net::HTTP.new(uri.host, uri.port)
    http.open_timeout = 30
    http.read_timeout = 900
    req = Net::HTTP::Post.new(uri)
    req['Content-Type'] = 'application/json'
    req.body = { model: model_name, messages: ollama_messages, stream: true }.to_json

    full = ''
    begin
      http.request(req) do |res|
        res.read_body do |chunk|
          chunk.split("\n").each do |line|
            line = line.strip
            next if line.empty?
            data = JSON.parse(line) rescue next
            content = data.dig('message', 'content') || ''
            next if content.empty?
            full += content
            out << "data: #{content.to_json}\n\n"
          end
        end
      end
    rescue => e
      out << "data: #{({ error: e.message }.to_json)}\n\n"
    end

    cache_append('MODEL', full) unless full.empty?
    out << "data: \"__DONE__\"\n\n"
    out.close
  end
end

# === Clear Cache ===
%w[get post].each do |method|
  send(method, '/api/clear') do
    content_type :json
    File.open(CACHE_LOG, 'w') do |f|
      f.puts("=== OllaOS Cache Log ===")
      f.puts("Session started: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}")
      f.puts("")
    end
    { status: 'cleared' }.to_json
  end
end

# === Restart Server ===
post '/api/restart' do
  Thread.new do
    sleep 1
    exec 'ruby', __FILE__
  end
  content_type :json
  { status: 'restarting' }.to_json
end

# === Stop Server ===
post '/api/shutdown' do
  Thread.new do
    sleep 1
    Process.kill('TERM', Process.pid)
  end
  content_type :json
  { status: 'shutting_down' }.to_json
end

# === Index ===
get '/' do
  content_type :html
  <<-HTML
    <!DOCTYPE html>
    <html>
    <head><title>OllaOS v2</title>#{STYLE}</head>
    <body>
      <h1>OllaOS v2</h1>
      <p>AI-powered Debian assistant. Everything logged to #{CACHE_LOG}.</p>
      <div class="nav">
        <a href="/ol_list" class="btn">List Models</a>
        <a href="/ol_pull" class="btn">Pull Model</a>
        <a href="/ol_rm" class="btn">Remove Model</a>
        <a href="/ol_run" class="btn">Chat</a>
        <a href="#" class="btn btn-danger" onclick="restartServer();return false;">Restart</a>
        <a href="#" class="btn btn-danger" onclick="stopServer();return false;">Stop</a>
      </div>
      <script>
        async function restartServer() {
          if (!confirm('Restart the server?')) return;
          try { await fetch('/api/restart', { method: 'POST' }); } catch(e) {}
          setTimeout(function(){ location.reload(); }, 2000);
        }
        async function stopServer() {
          if (!confirm('Stop the server?')) return;
          try { await fetch('/api/shutdown', { method: 'POST' }); } catch(e) {}
          document.body.innerHTML = '<h1>Server stopped</h1><p>You can close this tab.</p>';
        }
      </script>
    </body>
    </html>
  HTML
end
