function plugindef()
    finaleplugin.RequireDocument = false
    finaleplugin.RequireSelection = false
    finaleplugin.NoStore = true
    finaleplugin.ExecuteExternalCode = true
    finaleplugin.CategoryTags = "Document"
    finaleplugin.MinJWLuaVersion = 0.76
    return "Move Exports...", "Move Exports", "Move all exports to a folder called ‘-exports’"
end

local utils = require("library.utils")
local client = require("library.client")
local lfs = require("lfs")

local SUBFOLDER_NAME <const> = "-exports"
local MUSICXML_EXTENSION <const> = ".mxl"
local MUSESTYLE_EXTENSION <const> = ".mss"
local ENIGMAXML_EXTENSION <const> = ".enigmaxml"
local MUSX_EXTENSION <const> = ".musx"
local MUS_EXTENSION <const> = ".mus"

function select_directory()
    local default_folder_path = finale.FCString()
    default_folder_path:SetMusicFolderPath()
    local open_dialog = finale.FCFolderBrowseDialog(finenv.UI())
    open_dialog:SetWindowTitle(finale.FCString("Select folder containing Finale files"))
    open_dialog:SetFolderPath(default_folder_path)
    open_dialog:SetUseFinaleAPI(finenv:UI():IsOnMac())
    if not open_dialog:Execute() then
        return nil
    end
    local selected_folder = finale.FCString()
    open_dialog:GetFolderPath(selected_folder)
    selected_folder:AssureEndingPathDelimiter()
    return selected_folder.LuaString
end

local selected_folder = select_directory()
if not selected_folder then
    return
end

local function assure_export_folder_exists(path)
    local path_os = client.encode_with_client_codepage(path)
    local new_path_os = path_os .. SUBFOLDER_NAME
    local attr = lfs.attributes(new_path_os)
    if not attr then
        print ("creating " .. new_path_os)
        lfs.mkdir(new_path_os)
    elseif attr.mode ~= "directory" then
        error("unable to create " .. path .. SUBFOLDER_NAME .. " as a directory")
    end

     return new_path_os
end

local function move_to_export_folder(path, filename)
    local new_path_os = assure_export_folder_exists(path)
    local path_os = client.encode_with_client_codepage(path)
    local file_os = client.encode_with_client_codepage(filename)
    
    local command = string.format("mv %q %q", path_os .. file_os, new_path_os .. "/" .. file_os)
    local success, msg_or_status = os.execute(command)

    if not success then
        print("Unable to move " .. path .. filename .. ": " .. msg_or_status)
    else
        print("Moved " .. path .. filename .. " to " .. path .. SUBFOLDER_NAME .. "/" .. filename)
    end
    return success, msg_or_status
end

local SUBFOLDER_STRING <const> = "/" .. SUBFOLDER_NAME .. "/"

for path, filename in utils.eachfile(selected_folder, true) do
    if path:sub(-SUBFOLDER_STRING:len()) ~= SUBFOLDER_STRING then
        local _path, file, extension = utils.split_file_path(filename)
        if extension == MUSICXML_EXTENSION or extension == MUSESTYLE_EXTENSION or extension == ENIGMAXML_EXTENSION then
            move_to_export_folder(path, filename)
        elseif extension == MUS_EXTENSION then
            local attr = lfs.attributes(client.encode_with_client_codepage(path .. file .. MUSX_EXTENSION))
            if not attr or attr.mode ~= "file" then
                assure_export_folder_exists(path)
                -- We make a copy of the .mus file because FCDocument.Save will delete it
                local copy_path = path .. file .. " copy" .. extension
                local copy_command = string.format('cp -p %q %q', client.encode_with_client_codepage(path .. filename), client.encode_with_client_codepage(copy_path))
                if os.execute(copy_command) then
                    local document = finale.FCDocument()
                    if document:Open(finale.FCString(copy_path), true, nil, true, false, true) then
                        if not document:Save(finale.FCString(path .. SUBFOLDER_NAME .. "/" .. file .. MUSX_EXTENSION)) then
                            print("failed to save musx " .. path .. file .. MUSX_EXTENSION)
                        end
                        document:CloseCurrentDocumentAndWindow(false) -- rollback any edits
                        document:SwitchBack()
                        move_to_export_folder(path, file .. MUSX_EXTENSION)
                    else
                        print("failed to open document " .. path .. filename)
                    end
                    os.remove(copy_path)
                else
                    print ("failed to copy mus file to " .. copy_path)
                end
            end
        end
    end
end