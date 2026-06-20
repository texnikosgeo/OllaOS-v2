**OllaOS v2**  
**EXPERIMENTAL — USE AT YOUR OWN RISK**  
AI-powered Debian assistant. Chat with a local LLM (Ollama) that can  
   
 inspect and control your system through Ruby scripts.  
**Disclaimer**  
This software is provided **"AS IS"** with  **no warranty**. The AI model  
   
 may misinterpret your requests and execute unintended system commands,  
   
 modify files, or change system state. You are solely responsible for any  
   
 damage, data loss, or security issues. Run in an isolated environment  
   
 (VM, container, test hardware) until you fully understand the behavior.  
**How It Works**  
1. You type a message in the chat  
2. Ruby saves your message to OllaOS.Cache.txt  
3. Ruby detects keywords matching a tool (e.g. "disk space" → df)  
4. The tool script runs via Open3 — output goes to the cache file  
5. The **entire cache log** is sent to the LLM as context  
6. The LLM reads it and writes a response — also saved to the cache  
7. Every turn, the cache grows, giving the model full session history  
The LLM never calls tools directly. Ruby decides which tool to run  
   
 based on keyword patterns. The model just reads the cache and responds.  
**Files**  
| | |  
|-|-|  
| **File** | **Description** |   
| ol_sin.rb | Main Sinatra web app (routes, API, tool detection) |   
| OllaOS.Cache.txt | Session log — prompts, tool outputs, model replies |   
| df.rb | Show disk space usage |   
| ls.rb | List directory contents |   
| pwd.rb | Show current directory |   
| top.rb | Show running processes |   
| fastfetch.rb | Show system information |   
| geany.rb | Launch Geany text editor |   
| up_deb.rb | Update Debian packages |   
| web_search.rb | Look up information on the web |   
| wget.rb | Download a file |   
| web_scrub.rb | Extract text from a webpage |   
| ol_list.rb | List Ollama models |   
| ol_pull.rb | Download an Ollama model |   
| ol_rm.rb | Delete an Ollama model |   
| ol_run.rb | Run an Ollama model interactively |   
| tmux.rb | Launch tmux in a new terminal window |   
   
**Requirements**  
- Debian Linux (or any Linux with Ruby 3.x)  
- [Ollama running locally](https://ollama.com "https://ollama.com")  
- An Ollama model (e.g. samuser3/granite3.2-gemma3:4b)  
- Ruby gem: sinatra  
- Optional: ddgr, lynx, fastfetch, geany  
**Quick Start**  
cd v2/  
 gem install sinatra  
 ruby ol_sin.rb  
 # Open http://localhost:4567  
   
**Keywords**  
The backend detects these patterns in your messages:  
| | |  
|-|-|  
| **Tool** | **Triggers** |   
| df | disk, space, storage |   
| ls | list files, directory, contents |   
| pwd | current dir, where am I |   
| top | process, running, top |   
| fastfetch | system info, hardware, cpu, memory, specs |   
| geany | geany, text editor |   
| up_deb | update, upgrade, apt |   
| lookup | look up, search, find, what is, tell me |   
| wget | download file, wget |   
| scrub | scrub, extract, fetch URL |   
| ol_list | list models/ollama |   
| ol_pull | pull, download model |   
| ol_rm | remove, delete model |   
| tmux | tmux, terminal session, multiplexer |   
   
**Licensing**  
If you plan to distribute or modify this project, consider one of these  
   
 **copyleft** licenses — they all guarantee that source code stays open:  
| | |  
|-|-|  
| **License** | **Best for** |   
| **AGPLv3** | **Recommended** — closes the "web app loophole" (anyone using the app over a network must release their source too) |   
| GPLv3 | Standard copyleft for distributed software |   
| GPLv2 | Older but widely compatible |   
   
The simplest way: add a LICENSE file with the text of your chosen  
   
 license and a short header in each source file.  
**Credits**  
This project was built through conversation with:  
- [**OpenCode** — the CLI tool that served as the  
   
 development interface](https://opencode.ai "https://opencode.ai")  
- **Big Pickle** model from  **ZEN AI** — the AI that read, wrote, and  
 debugged every line of code  

And Geo.  

Without them, OllaOS would not exist.  
