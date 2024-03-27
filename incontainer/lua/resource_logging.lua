-- Lua-Skript zur Protokollierung von Informationen zu angeforderten Dateiressourcen mit IP-Adresse

-- Funktion zum Erstellen des Dateinamens basierend auf dem aktuellen Datum
local function get_log_filename()
    local date_format = "%Y-%m-%d"  -- Format für das Datum (Jahr-Monat-Tag)
    return "/tmp/resource_logging_" .. os.date(date_format) .. ".log"
end

-- Öffnen des Log-Files im Anhänge-Modus mit dem aktuellen Datum im Dateinamen
local file_path = get_log_filename()
local file = io.open(file_path, "a")

if file then
    -- Holen der angeforderten URI
    local requested_uri = ngx.var.request_uri

    -- Holen der IP-Adresse des aufrufenden Clients
    local client_ip = ngx.var.remote_addr

    -- Überprüfen, ob die angeforderte Ressource eine Datei ist und nicht /favicon.ico
    if not (requested_uri:match("/$") or requested_uri == "/favicon.ico") then
        -- Zeitstempel des Zugriffs
        local timestamp = ngx.time()

        -- Formatieren der Daten mit IP-Adresse
        local data = string.format("[%s] %s | Client IP: %s\n", os.date("%Y-%m-%d %H:%M:%S", timestamp), requested_uri, client_ip)

        -- Schreiben der Daten in die Datei
        file:write(data)
    end

    -- Schließen der Datei
    file:close()
else
    ngx.log(ngx.ERR, "Couldn't open the file: " .. file_path)
end
