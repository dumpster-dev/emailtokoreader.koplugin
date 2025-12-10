local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local InfoMessage = require("ui/widget/infomessage")
local _ = require("gettext")
local logger = require("logger")
local DataStorage = require("datastorage")
local lfs = require("libs/libkoreader-lfs")

-- Load config
local config_path = require("ffi/util").joinPath(
    DataStorage: getDataDir(), 
    "plugins/emailtokoreader.koplugin/config.lua"
)

local config = {}
local ok, loaded_config = pcall(dofile, config_path)
if ok and loaded_config then
    config = loaded_config
else
    config = {
        imap_server = "imap.gmail.com",
        imap_port = 993,
        email = "your-email@gmail.com",
        password = "your-app-password",
        download_path = "/mnt/us/books/emailed/",
        use_ssl = true,
        debug_mode = false,
        allowed_email = "your-email+koreader@gmail.com",
    }
end

-- Size limit:  5MB (base64 encoded = ~6.7MB)
local MAX_ATTACHMENT_SIZE = 5 * 1024 * 1024  -- 5MB decoded
local MAX_BASE64_SIZE = 7 * 1024 * 1024      -- ~7MB base64 (encodes ~5MB)

-- Validate and set safe fallback path
local function validate_and_set_download_path()
    local safe_fallback_path
    
    local ok_settings, G_reader_settings = pcall(require, "luasettings")
    if ok_settings then
        local ok_open, settings = pcall(G_reader_settings.open, G_reader_settings, 
            DataStorage:getDataDir() .. "/settings.reader.lua")
        if ok_open and settings then
            local ok_read, userHome = pcall(settings.readSetting, settings, "home_dir")
            if ok_read and userHome and userHome ~= "" then
                safe_fallback_path = userHome
                if not safe_fallback_path:match("/$") then
                    safe_fallback_path = safe_fallback_path .. "/"
                end
            end
        end
    end
    
    if not safe_fallback_path then
        local koreader_home = DataStorage:getDataDir()
        safe_fallback_path = koreader_home ..  "/downloads/"
    end
    
    local path_valid = false
    if config.download_path and config.download_path ~= "" then
        if not config.download_path:match("/$") then
            config.download_path = config.download_path ..  "/"
        end
        
        local attr = lfs.attributes(config. download_path)
        if attr and attr.mode == "directory" then
            local test_file = config.download_path .. ".koreader_write_test"
            local f = io.open(test_file, "w")
            if f then
                f:close()
                os.remove(test_file)
                path_valid = true
            end
        end
    end
    
    if not path_valid and safe_fallback_path then
        local fallback_attr = lfs.attributes(safe_fallback_path)
        if not fallback_attr then
            lfs.mkdir(safe_fallback_path)
        end
        config.download_path = safe_fallback_path
        config.using_fallback_path = true
    else
        config.using_fallback_path = false
    end
end

validate_and_set_download_path()

local emailtokoreader = WidgetContainer:extend{
    name = "Email to KOReader",
    is_doc_only = false,
}

local function save_config_to_file(plugin_path)
    local config_file = plugin_path .. "/config.lua"
    local f, err = io.open(config_file, "w")
    if not f then
        return false, err
    end
    
    local function escape_string(s)
        if not s then return "" end
        return s:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n')
    end
    
    local success, write_err = pcall(function()
        f:write("return {\n")
        f:write(string.format('    email = "%s",\n', escape_string(config.email or "")))
        f:write(string.format('    password = "%s",\n', escape_string(config.password or "")))
        f:write(string.format('    imap_server = "%s",\n', escape_string(config.imap_server or "imap.gmail.com")))
        f:write(string.format('    imap_port = %d,\n', config.imap_port or 993))
        f:write(string.format('    use_ssl = %s,\n', config.use_ssl and "true" or "false"))
        f:write(string.format('    download_path = "%s",\n', escape_string(config.download_path or "/mnt/us/books/emailed/")))
        f:write(string.format('    debug_mode = %s,\n', config.debug_mode and "true" or "false"))
        f:write(string.format('    allowed_email = "%s",\n', escape_string(config.allowed_email or "")))
        f:write("}\n")
    end)
    
    f:close()
    
    if success then
        return true
    else
        return false, write_err
    end
end

-- Check if file has supported extension
local function is_supported_file(filename)
    local supported_extensions = {
        ["epub"] = true,
        ["pdf"] = true,
        ["mobi"] = true,
        ["azw3"] = true,
        ["azw"] = true,
        ["cbz"] = true,
        ["txt"] = true,
        ["fb2"] = true,
        ["djvu"] = true,
        ["doc"] = true,
        ["docx"] = true,
        ["rtf"] = true,
        ["html"] = true,
        ["htm"] = true,
        ["chm"] = true,
        ["pdb"] = true,
        ["prc"] = true,
    }
    
    if not filename then return false end
    
    local ext = filename:match("%.([^%. ]+)$")
    if not ext then return false end
    
    return supported_extensions[ext: lower()] or false
end

function emailtokoreader:init()
    self.ui.menu: registerToMainMenu(self)
end

function emailtokoreader: addToMainMenu(menu_items)
    menu_items.emailtokoreader = {
        text = _("Email to KOReader"),
        sorting_hint = "tools",
        sub_item_table = {
            {
                text = _("Check Inbox"),
                callback = function()
                    self:checkInbox()
                end,
            },
            {
                text = _("Test Connection"),
                callback = function()
                    self:testConnection()
                end,
            },
            {
                text = _("Configure Settings"),
                callback = function()
                    self:showSettings()
                end,
            },
            {
                text = _("Toggle Debug Mode"),
                checked_func = function()
                    return config.debug_mode
                end,
                callback = function()
                    config.debug_mode = not config.debug_mode
                    save_config_to_file(self.path)
                    UIManager:show(InfoMessage:new{
                        text = config.debug_mode and _("Debug mode enabled") or _("Debug mode disabled"),
                        timeout = 2,
                    })
                end,
            },
            {
                text = _("View Download Path"),
                callback = function()
                    local path_status = config.using_fallback_path and "FALLBACK PATH" or "Configured path"
                    UIManager:show(InfoMessage:new{
                        text = _(path_status ..  "\n\n" .. config.download_path),
                        timeout = 4,
                    })
                end,
            },
            {
                text = _("About"),
                callback = function()
                    UIManager:show(InfoMessage:new{
                        text = _("Email to KOReader v1.5.0\n\nDownload ebook attachments from email.\n\nMax attachment size: 5MB\n\nSupported:  EPUB, PDF, MOBI, AZW3, CBZ, TXT, FB2, DJVU"),
                        timeout = 5,
                    })
                end,
            },
        },
    }
end

function emailtokoreader:showSettings()
    local MultiInputDialog = require("ui/widget/multiinputdialog")
    
    local settings_dialog
    settings_dialog = MultiInputDialog:new{
        title = _("Email to KOReader Settings"),
        fields = {
            {
                text = config.email or "",
                hint = "your.email@gmail.com",
                description = _("Email Address"),
            },
            {
                text = config.password or "",
                hint = "app-specific password",
                text_type = "password",
                description = _("App Password"),
            },
            {
                text = config.imap_server or "imap.gmail.com",
                hint = "imap.gmail.com",
                description = _("IMAP Server"),
            },
            {
                text = tostring(config.imap_port or 993),
                hint = "993",
                description = _("IMAP Port"),
            },
            {
                text = config.download_path or "",
                hint = "/mnt/us/books/emailed/",
                description = _("Download Path"),
            },
            {
                text = config.allowed_email or "",
                hint = "your-email+koreader@gmail.com",
                description = _("Filter:  Only To Address (optional)"),
            },
        },
        buttons = {
            {
                {
                    text = _("Cancel"),
                    callback = function()
                        UIManager:close(settings_dialog)
                    end,
                },
                {
                    text = _("Save"),
                    is_enter_default = true,
                    callback = function()
                        local fields = settings_dialog:getFields()
                        
                        config.email = fields[1] or config.email
                        config.password = fields[2] or config.password
                        config.imap_server = fields[3] or config.imap_server
                        config.imap_port = tonumber(fields[4]) or 993
                        config.download_path = fields[5] or config.download_path
                        config.allowed_email = fields[6] or ""
                        
                        if config.download_path and not config.download_path:match("/$") then
                            config.download_path = config.download_path .. "/"
                        end
                        
                        local success, err = save_config_to_file(self.path)
                        UIManager:close(settings_dialog)
                        
                        if success then
                            UIManager:show(InfoMessage: new{
                                text = _("Settings saved! "),
                                timeout = 2,
                            })
                        else
                            UIManager:show(InfoMessage:new{
                                text = _("Failed to save:  " .. (err or "unknown")),
                                timeout = 3,
                            })
                        end
                    end,
                },
            },
        },
    }
    
    UIManager:show(settings_dialog)
    settings_dialog:onShowKeyboard()
end

function emailtokoreader:testConnection()
    if not config.email or config.email == "" or config.email == "your-email@gmail.com" then
        UIManager: show(InfoMessage:new{
            text = _("Please configure your email first."),
            timeout = 3,
        })
        return
    end

    if not config.password or config.password == "" or config.password == "your-app-password" then
        UIManager:show(InfoMessage:new{
            text = _("Please configure your password first."),
            timeout = 3,
        })
        return
    end

    UIManager:show(InfoMessage:new{
        text = _("Testing connection..."),
        timeout = 2,
    })

    UIManager:scheduleIn(0.5, function()
        local socket = require("socket")
        local conn = socket.tcp()
        if not conn then
            UIManager:show(InfoMessage:new{
                text = _("Cannot create socket"),
                timeout = 3,
            })
            return
        end

        conn:settimeout(10)
        local ok, err = conn:connect(config.imap_server, config.imap_port)

        if not ok then
            conn:close()
            UIManager: show(InfoMessage:new{
                text = _("Connection failed: " .. tostring(err)),
                timeout = 4,
            })
            return
        end

        if config.use_ssl then
            local ssl_ok, ssl = pcall(require, "ssl")
            if ssl_ok then
                conn = ssl.wrap(conn, {
                    mode = "client",
                    protocol = "tlsv1_2",
                    verify = "none",
                })
                local hs_ok, hs_err = conn:dohandshake()
                if not hs_ok then
                    conn:close()
                    UIManager:show(InfoMessage:new{
                        text = _("SSL failed: " .. tostring(hs_err)),
                        timeout = 4,
                    })
                    return
                end
            end
        end

        conn:receive("*l")
        conn:send(string.format('A001 LOGIN "%s" "%s"\r\n', config.email, config.password))

        local login_ok = false
        for i = 1, 5 do
            local line = conn:receive("*l")
            if line then
                if line:match("^A001 OK") then
                    login_ok = true
                    break
                elseif line:match("^A001 NO") or line:match("^A001 BAD") then
                    break
                end
            end
        end

        conn:send("A002 LOGOUT\r\n")
        conn:receive("*l")
        conn:close()

        if login_ok then
            UIManager: show(InfoMessage:new{
                text = _("Connection successful!"),
                timeout = 3,
            })
        else
            UIManager:show(InfoMessage:new{
                text = _("Login failed. Check email and app password."),
                timeout = 4,
            })
        end
    end)
end

function emailtokoreader:checkInbox()
    if not config.email or config.email == "" or config.email == "your-email@gmail.com" then
        UIManager:show(InfoMessage:new{
            text = _("Please configure your email first."),
            timeout = 3,
        })
        return
    end

    if not config.password or config.password == "" or config.password == "your-app-password" then
        UIManager:show(InfoMessage:new{
            text = _("Please configure your password first."),
            timeout = 3,
        })
        return
    end

    UIManager:show(InfoMessage:new{
        text = _("Checking inbox.. .\nThis may take 2-3 minutes."),
        timeout = 2,
    })
    
    UIManager:scheduleIn(1, function()
        local success, result = pcall(function()
            return self:fetchEmails()
        end)
        
        if not success then
            UIManager:show(InfoMessage:new{
                text = _("Error:  " .. tostring(result)),
                timeout = 5,
            })
        elseif result.success then
            if result.downloaded > 0 then
                local message = "Downloaded " .. result.downloaded .. " file(s):\n\n"
                for i, filename in ipairs(result.files) do
                    message = message .. "- " .. filename .. "\n"
                end
                
                -- Add info about skipped emails
                if result.skipped_filter and result.skipped_filter > 0 then
                    message = message .. "\n(" .. result.skipped_filter .. " skipped by filter)"
                end
                if result.skipped_size and result.skipped_size > 0 then
                    message = message .. "\n(" .. result.skipped_size .. " skipped:  >5MB)"
                end
                
                UIManager:show(InfoMessage:new{
                    text = _(message),
                    timeout = 6,
                })
                
                UIManager:scheduleIn(0.5, function()
                    local FileManager = require("apps/filemanager/filemanager")
                    if FileManager.instance then
                        FileManager.instance:onRefresh()
                    end
                end)
            else
                local message = "No new files found."
                if result.skipped_filter and result.skipped_filter > 0 then
                    message = message .. "\n(" .. result.skipped_filter .. " skipped by filter)"
                end
                if result.skipped_size and result.skipped_size > 0 then
                    message = message .. "\n(" .. result.skipped_size .. " skipped: >5MB size limit)"
                end
                UIManager:show(InfoMessage:new{
                    text = _(message),
                    timeout = 4,
                })
            end
        else
            UIManager:show(InfoMessage:new{
                text = _("Error: " .. (result.error or "Unknown")),
                timeout = 5,
            })
        end
    end)
end

function emailtokoreader:fetchEmails()
    -- Base64 decode function
    local function base64_decode(data)
        if not data or data == "" then return nil end
        local b = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
        data = string.gsub(data, '[^'..b..'=]', '')
        return (data:gsub('.', function(x)
            if x == '=' then return '' end
            local r, f = '', (b:find(x) - 1)
            for i = 6, 1, -1 do
                r = r .. (f % 2^i - f % 2^(i-1) > 0 and '1' or '0')
            end
            return r
        end):gsub('%d%d%d%d%d%d%d%d', function(x)
            if #x ~= 8 then return '' end
            local c = 0
            for i = 1, 8 do
                c = c + (x:sub(i, i) == '1' and 2^(8-i) or 0)
            end
            return string.char(c)
        end))
    end
    
    -- URL decode
    local function url_decode(str)
        if not str then return nil end
        str = string.gsub(str, "+", " ")
        str = string.gsub(str, "%%(%x%x)", function(h)
            return string.char(tonumber(h, 16))
        end)
        return str
    end
    
    -- Decode RFC 2047
    local function decode_rfc2047(str)
        if not str then return str end
        str = str:gsub("%? =%s+=%? ", "? ==? ")
        return str:gsub("=%? ([^%?]+)%?([bBqQ])%?([^%?]*)%?=", function(charset, encoding, data)
            if encoding: lower() == "b" then
                return base64_decode(data) or data
            elseif encoding:lower() == "q" then
                data = data:gsub("_", " ")
                data = data:gsub("=(%x%x)", function(h)
                    return string.char(tonumber(h, 16))
                end)
                return data
            end
            return data
        end)
    end

    -- Unfold headers (RFC 2822:  lines starting with whitespace are continuations)
    local function unfold_headers(headers)
        headers = headers: gsub("\r\n[ \t]+", " ")
        headers = headers:gsub("\n[ \t]+", " ")
        return headers
    end
    
    -- Decode filename
    local function decode_filename(filename)
        if not filename then return nil end
        filename = filename:gsub('^"(.*)"$', '%1')
        filename = filename: gsub("^'(.*)'$", '%1')
        filename = filename:match("^%s*(.-)%s*$")
        if filename: match("=%? ") then
            filename = decode_rfc2047(filename)
        end
        return filename
    end
    
    -- Sanitize filename
    local function sanitize_filename(filename)
        if not filename then return nil end
        filename = filename:gsub('[<>:"/\\|%? %*]', '_')
        filename = filename:gsub('%c', '')
        if #filename > 200 then
            local name, ext = filename:match("^(. +)%.([^%.]+)$")
            if name and ext then
                filename = name: sub(1, 195) .. "." .. ext
            end
        end
        return filename
    end
    
    -- Write file safely
    local function writeFile(filepath, data)
        if not filepath or not data then
            return false, "Invalid filepath or data"
        end
        local temp_file = filepath ..  ".tmp"
        local f, err = io.open(temp_file, "wb")
        if not f then
            return false, "Cannot open file:  " .. tostring(err)
        end
        
        local chunk_size = 8192
        for i = 1, #data, chunk_size do
            local chunk = data:sub(i, math.min(i + chunk_size - 1, #data))
            f:write(chunk)
        end
        f:close()
        
        local attr = lfs.attributes(temp_file)
        if not attr or attr.size ~= #data then
            os.remove(temp_file)
            return false, "Size mismatch"
        end
        
        os.remove(filepath)
        local ok = os.rename(temp_file, filepath)
        if not ok then
            os.remove(temp_file)
            return false, "Rename failed"
        end
        return true
    end
    
    -- Extract filename from headers
    local function extract_filename(headers)
        local unfolded = unfold_headers(headers)
        local filename = nil
        
        -- RFC 2231
        local encoded = unfolded:match("[Ff]ilename%*%s*=%s*[Uu][Tt][Ff]%-?8''([^%s;%c]+)")
        if encoded then
            filename = url_decode(encoded)
            if filename and is_supported_file(filename) then
                return filename
            end
        end
        
        -- Quoted filename
        filename = unfolded:match('[Ff]ilename%s*=%s*"([^"]+)"')
        if filename then
            filename = decode_filename(filename)
            if filename and is_supported_file(filename) then
                return filename
            end
        end
        
        -- Unquoted filename
        filename = unfolded:match('[Ff]ilename%s*=%s*([^;%s%c]+)')
        if filename then
            filename = decode_filename(filename)
            if filename and is_supported_file(filename) then
                return filename
            end
        end
        
        -- name parameter
        filename = unfolded:match('[Nn]ame%s*=%s*"([^"]+)"')
        if filename then
            filename = decode_filename(filename)
            if filename and is_supported_file(filename) then
                return filename
            end
        end
        
        return nil
    end
    
    -- Check recipient
    local function check_recipient(message, allowed)
        if not allowed or allowed == "" or allowed == "your-email+koreader@gmail.com" then
            return true
        end
        
        local filter = allowed:lower()
        local to_header = message:match("[Tt][Oo]:%s*([^\r\n]+)")
        if to_header and to_header:lower():find(filter, 1, true) then
            return true
        end
        
        local cc_header = message:match("[Cc][Cc]:%s*([^\r\n]+)")
        if cc_header and cc_header:lower():find(filter, 1, true) then
            return true
        end
        
        local delivered = message:match("[Dd]elivered%-[Tt]o:%s*([^\r\n]+)")
        if delivered and delivered: lower():find(filter, 1, true) then
            return true
        end
        
        return false
    end
    
    -- Check if message has attachment exceeding size limit
    -- Returns:  has_large_attachment (bool), attachment_size_mb (number or nil)
    local function check_attachment_size(message)
        -- Look for base64 encoded content
        local boundary = message:match('[Bb]oundary%s*=%s*"([^"]+)"')
        if not boundary then
            boundary = message:match("[Bb]oundary%s*=%s*([^;%s%c]+)")
        end
        
        if not boundary then
            return false, nil
        end
        
        local marker = "--" .. boundary
        local pos = 1
        
        while true do
            local bpos = message:find(marker, pos, true)
            if not bpos then break end
            
            local after = bpos + #marker
            if message:sub(after, after + 1) == "--" then
                break
            end
            
            local line_end = message:find("\n", after)
            if not line_end then break end
            
            local part_start = line_end + 1
            local next_bpos = message:find(marker, part_start, true)
            local part_end = next_bpos and (next_bpos - 1) or #message
            
            if part_start < part_end then
                local part = message:sub(part_start, part_end)
                local header_end = part:find("\r\n\r\n") or part: find("\n\n")
                
                if header_end then
                    local headers = part:sub(1, header_end - 1)
                    local unfolded = unfold_headers(headers)
                    
                    -- Check if this part has a filename and is base64
                    local has_file = unfolded:match('[Ff]ilename') or unfolded:match('[Nn]ame%s*=')
                    local has_b64 = unfolded:lower():match("content%-transfer%-encoding:%s*base64")
                    
                    if has_file and has_b64 then
                        -- Get the body and check size
                        local body_start = header_end + (part:sub(header_end, header_end + 1) == "\r\n" and 4 or 2)
                        local body = part:sub(body_start)
                        local base64_data = body:gsub("%s+", "")
                        local base64_size = #base64_data
                        
                        -- Estimate decoded size (base64 is ~4/3 of original)
                        local estimated_size = math.floor(base64_size * 3 / 4)
                        
                        logger.info("Attachment base64 size:", base64_size, "estimated decoded:", estimated_size)
                        
                        if base64_size > MAX_BASE64_SIZE or estimated_size > MAX_ATTACHMENT_SIZE then
                            local size_mb = estimated_size / (1024 * 1024)
                            logger.info("Attachment too large:", string.format("%.2f MB", size_mb))
                            return true, size_mb
                        end
                    end
                end
            end
            
            pos = part_start
        end
        
        return false, nil
    end
    
    -- Save debug file
    local function save_debug(msg_id, content)
        if not config.debug_mode then return end
        local path = config.download_path .. "debug_" .. tostring(msg_id) .. ".txt"
        local f = io.open(path, "w")
        if f then
            -- Limit debug file size to 100KB
            if #content > 102400 then
                f:write(content:sub(1, 102400))
                f:write("\n\n...  [truncated] ...")
            else
                f:write(content)
            end
            f: close()
        end
    end
    
    -- Process MIME part
    local function process_part(part, files, count)
        local header_end = part:find("\r\n\r\n") or part:find("\n\n")
        if not header_end then
            return count, false
        end
        
        local headers = part:sub(1, header_end - 1)
        local body_start = part:find("\r\n\r\n")
        local body
        if body_start then
            body = part:sub(body_start + 4)
        else
            body_start = part:find("\n\n")
            if body_start then
                body = part:sub(body_start + 2)
            else
                return count, false
            end
        end
        
        -- Skip nested multipart
        if headers:match('[Bb]oundary%s*=') then
            return count, false
        end
        
        local filename = extract_filename(headers)
        if not filename then
            return count, false
        end
        
        logger.info("Found attachment:", filename)
        
        -- Check for base64 encoding
        local unfolded_headers = unfold_headers(headers)
        if not unfolded_headers:lower():match("content%-transfer%-encoding:%s*base64") then
            logger.info("Not base64 encoded")
            return count, false
        end
        
        local base64_data = body:gsub("%s+", "")
        local base64_size = #base64_data
        logger.info("Base64 size:", base64_size)
        
        -- Check size limit
        if base64_size > MAX_BASE64_SIZE then
            local size_mb = (base64_size * 3 / 4) / (1024 * 1024)
            logger.warn("Attachment too large:", string.format("%.2f MB", size_mb), "- skipping")
            return count, true  -- Return true to indicate size limit exceeded
        end
        
        if base64_size < 100 then
            logger.warn("Base64 data too small")
            return count, false
        end
        
        local decoded = base64_decode(base64_data)
        base64_data = nil
        collectgarbage("collect")
        
        if not decoded or #decoded == 0 then
            logger.err("Decode failed")
            return count, false
        end
        
        -- Check decoded size
        if #decoded > MAX_ATTACHMENT_SIZE then
            local size_mb = #decoded / (1024 * 1024)
            logger.warn("Decoded file too large:", string.format("%.2f MB", size_mb), "- skipping")
            decoded = nil
            collectgarbage("collect")
            return count, true  -- Return true to indicate size limit exceeded
        end
        
        logger.info("Decoded size:", #decoded)
        
        local safe_name = sanitize_filename(filename)
        local filepath = config.download_path .. safe_name
        
        if lfs.attributes(filepath) then
            local name, ext = safe_name:match("^(.+)%.([^%.]+)$")
            if name and ext then
                safe_name = name ..  "_" .. os.time() .. "." .. ext
            else
                safe_name = safe_name ..  "_" .. os.time()
            end
            filepath = config.download_path .. safe_name
        end
        
        logger.info("Saving to:", filepath)
        local ok, err = writeFile(filepath, decoded)
        decoded = nil
        collectgarbage("collect")
        
        if ok then
            count = count + 1
            table.insert(files, safe_name)
            logger.info("Saved:", safe_name)
        else
            logger.err("Write failed:", err)
        end
        
        return count, false
    end
    
    -- Find attachments recursively
    -- Returns: count, size_exceeded (bool)
    local function find_attachments(content, boundary, files, count, depth)
        depth = depth or 0
        if depth > 5 then return count, false end
        
        local marker = "--" .. boundary
        local parts = {}
        local pos = 1
        local size_exceeded = false
        
        while true do
            local bpos = content:find(marker, pos, true)
            if not bpos then break end
            
            local after = bpos + #marker
            if content:sub(after, after + 1) == "--" then
                break
            end
            
            local line_end = content: find("\n", after)
            if not line_end then break end
            
            local part_start = line_end + 1
            local next_bpos = content:find(marker, part_start, true)
            local part_end = next_bpos and (next_bpos - 1) or #content
            
            while part_end > part_start and (content:byte(part_end) == 10 or content:byte(part_end) == 13) do
                part_end = part_end - 1
            end
            
            if part_start <= part_end then
                local part = content:sub(part_start, part_end)
                if #part > 10 then
                    table.insert(parts, part)
                end
            end
            
            pos = part_start
        end
        
        logger.info("Found", #parts, "parts at depth", depth)
        
        for i, part in ipairs(parts) do
            local header_end = part:find("\r\n\r\n") or part:find("\n\n")
            if header_end then
                local headers = part:sub(1, header_end)
                local unfolded = unfold_headers(headers)
                
                local nested = unfolded:match('[Bb]oundary%s*=%s*"([^"]+)"')
                if not nested then
                    nested = unfolded:match("[Bb]oundary%s*=%s*([^;%s%c]+)")
                end
                
                if nested then
                    logger.info("Nested boundary:", nested)
                    local nested_count, nested_exceeded = find_attachments(part, nested, files, count, depth + 1)
                    count = nested_count
                    if nested_exceeded then
                        size_exceeded = true
                    end
                else
                    local has_file = unfolded:match('[Ff]ilename') or unfolded:match('[Nn]ame%s*=')
                    local has_b64 = unfolded:lower():match("content%-transfer%-encoding:%s*base64")
                    
                    if has_file and has_b64 then
                        local new_count, part_exceeded = process_part(part, files, count)
                        count = new_count
                        if part_exceeded then
                            size_exceeded = true
                        end
                    end
                end
            end
        end
        
        return count, size_exceeded
    end
    
    -- Main logic
    logger.info("fetchEmails starting")
    logger.info("Download path:", config.download_path)
    logger.info("Max attachment size:", MAX_ATTACHMENT_SIZE / (1024 * 1024), "MB")
    
    local path_attr = lfs.attributes(config.download_path)
    if not path_attr then
        lfs.mkdir(config.download_path)
    end
    
    local socket = require("socket")
    local conn = socket.tcp()
    if not conn then
        return {success = false, error = "Cannot create socket"}
    end
    
    conn:settimeout(30)
    local ok, err = conn:connect(config.imap_server, config.imap_port)
    if not ok then
        conn:close()
        return {success = false, error = "Connect failed: " .. tostring(err)}
    end
    
    if config.use_ssl then
        local ssl_ok, ssl = pcall(require, "ssl")
        if ssl_ok then
            conn = ssl.wrap(conn, {
                mode = "client",
                protocol = "tlsv1_2",
                verify = "none",
            })
            local hs_ok, hs_err = conn:dohandshake()
            if not hs_ok then
                conn:close()
                return {success = false, error = "SSL failed: " .. tostring(hs_err)}
            end
        else
            conn:close()
            return {success = false, error = "SSL not available"}
        end
    end
    
    conn:receive("*l")
    
    conn:send(string.format('A001 LOGIN "%s" "%s"\r\n', config.email, config.password))
    local login_ok = false
    for i = 1, 10 do
        local line = conn:receive("*l")
        if line then
            if line:match("^A001 OK") then
                login_ok = true
                break
            elseif line:match("^A001 NO") or line:match("^A001 BAD") then
                conn:close()
                return {success = false, error = "Login failed"}
            end
        end
    end
    if not login_ok then
        conn:close()
        return {success = false, error = "Login timeout"}
    end
    
    logger.info("Login OK")
    
    conn:send("A002 SELECT INBOX\r\n")
    for i = 1, 15 do
        local line = conn:receive("*l")
        if line and line:match("^A002 OK") then break end
    end
    
    conn:send("A003 SEARCH UNSEEN\r\n")
    local msg_ids = {}
    for i = 1, 5 do
        local line = conn:receive("*l")
        if line then
            if line:match("^%* SEARCH") then
                for id in line:gmatch("%d+") do
                    table.insert(msg_ids, id)
                end
            end
            if line:match("^A003 OK") then break end
        end
    end
    
    logger.info("Found", #msg_ids, "unseen")
    
    -- Reverse for newest first
    local reversed = {}
    for i = #msg_ids, 1, -1 do
        table.insert(reversed, msg_ids[i])
    end
    msg_ids = reversed
    
    -- Limit
    if #msg_ids > 10 then
        local limited = {}
        for i = 1, 10 do
            table.insert(limited, msg_ids[i])
        end
        msg_ids = limited
    end
    
    local downloaded = 0
    local files = {}
    local skipped_filter = 0
    local skipped_size = 0
    local cmd = 100
    
    for idx, msg_id in ipairs(msg_ids) do
        logger.info("Processing message", idx, "ID:", msg_id)
        
        cmd = cmd + 1
        local tag = "A" .. cmd
        conn:send(tag ..  " FETCH " .. msg_id .. " BODY[]\r\n")
        
        local lines = {}
        local count = 0
        local skip_first = true
        
        while true do
            local line = conn:receive("*l")
            if not line then break end
            count = count + 1
            
            if line:match("^" .. tag .. " OK") then break end
            if line:match("^" .. tag .. " NO") or line:match("^" .. tag .. " BAD") then break end
            
            if skip_first and line:match("^%* %d+ FETCH") then
                skip_first = false
            elseif line ~= ")" then
                table.insert(lines, line)
            end
            
            if count > 100000 then
                while true do
                    local rest = conn:receive("*l")
                    if not rest or rest: match("^" .. tag) then break end
                end
                break
            end
        end
        
        if #lines == 0 then
            goto continue
        end
        
        local message = table.concat(lines, "\n")
        lines = nil
        collectgarbage("collect")
        
        save_debug(msg_id, message)
        
        -- Check recipient filter
        if not check_recipient(message, config.allowed_email) then
            logger.info("Skipped by filter")
            skipped_filter = skipped_filter + 1
            message = nil
            collectgarbage("collect")
            goto continue
        end
        
        -- Check attachment size before processing
        local has_large, size_mb = check_attachment_size(message)
        if has_large then
            logger.info("Skipping message - attachment too large:", string.format("%.2f MB", size_mb or 0))
            skipped_size = skipped_size + 1
            message = nil
            collectgarbage("collect")
            goto continue
        end
        
        -- Find boundary
        local header_section = message:match("^(.-)\r?\n\r?\n") or message:sub(1, 2000)
        local unfolded_header = unfold_headers(header_section)
        
        local boundary = unfolded_header: match('[Bb]oundary%s*=%s*"([^"]+)"')
        if not boundary then
            boundary = unfolded_header:match("[Bb]oundary%s*=%s*([^;%s%c]+)")
        end
        
        if not boundary then
            logger.info("No boundary")
            message = nil
            collectgarbage("collect")
            goto continue
        end
        
        logger.info("Boundary:", boundary)
        
        local msg_down, msg_size_exceeded = find_attachments(message, boundary, files, 0, 0)
        downloaded = downloaded + msg_down
        
        -- If any attachment in this message exceeded size, count it
        if msg_size_exceeded and msg_down == 0 then
            skipped_size = skipped_size + 1
        end
        
        logger.info("Downloaded", msg_down, "from message")
        
        message = nil
        collectgarbage("collect")
        
        ::continue::
    end
    
    cmd = cmd + 1
    conn:send("A" .. cmd .. " LOGOUT\r\n")
    pcall(function() conn:receive("*l") end)
    conn:close()
    
    collectgarbage("collect")
    
    logger.info("Done.  Downloaded:", downloaded, "Skipped by filter:", skipped_filter, "Skipped by size:", skipped_size)
    
    return {
        success = true,
        downloaded = downloaded,
        files = files,
        skipped_filter = skipped_filter,
        skipped_size = skipped_size,
        -- Keep backward compatibility
        skipped = skipped_filter
    }
end

return emailtokoreader