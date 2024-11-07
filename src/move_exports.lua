function plugindef()
    finaleplugin.RequireDocument = false
    finaleplugin.RequireSelection = false
    finaleplugin.NoStore = true
    finaleplugin.ExecuteExternalCode = true
    finaleplugin.CategoryTags = "Document"
    finaleplugin.MinJWLuaVersion = 0.76
    return "Move Exports...", "Move Exports", "Copy Finale docs to Finale 27 versions and move them and all exports to a folder called ‘-exports’"
end

local utils = require("library.utils")
local client = require("library.client")
local mixin = require("library.mixin")

local lfs = require("lfs")

local SUBFOLDER_NAME <const> = "-exports"
local MUSICXML_EXTENSION <const> = ".mxl"
local MUSESTYLE_EXTENSION <const> = ".mss"
local ENIGMAXML_EXTENSION <const> = ".enigmaxml"
local MUSX_EXTENSION <const> = ".musx"
local MUS_EXTENSION <const> = ".mus"

local TIMER_ID <const> = 1

local function select_directory()
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

    local format_string = finenv.UI():IsOnMac() and "mv %q %q" or "move %q %q"
    local command = string.format(format_string, path_os .. file_os, new_path_os .. "/" .. file_os)
    local success, msg_or_status = os.execute(command)

    if not success then
        print("Unable to move " .. path .. filename .. ": " .. msg_or_status)
    else
        print("Moved " .. path .. filename .. " to " .. path .. SUBFOLDER_NAME .. "/" .. filename)
    end
    return success, msg_or_status
end

local function export_updated_document(path, file, extension)
    local calc_mod_time = function(utf8_path)
        local attr = lfs.attributes(client.encode_with_client_codepage(utf8_path))
        if attr then
            return attr.modification
        end
        return -1
    end

    local document_path <const> = path .. file .. extension
    local updated_docpath <const> = path .. SUBFOLDER_NAME .. "/" .. file .. ".fin27" .. MUSX_EXTENSION
    if calc_mod_time(updated_docpath) > calc_mod_time(document_path) then
        return
    end

    assure_export_folder_exists(path)
    -- We make a copy of the original .mus or .musx file because FCDocument.Save may delete it
    local copy_path <const> = path .. file .. " copy" .. extension
    local format_string = finenv.UI():IsOnMac() and "cp -p %q %q" or "copy /b %q %q"
    local copy_command = string.format(format_string, client.encode_with_client_codepage(document_path),
            client.encode_with_client_codepage(copy_path))
    if os.execute(copy_command) then
        local document = finale.FCDocument()
        if document:Open(finale.FCString(copy_path), true, nil, true, false, true) then
            if not document:Save(finale.FCString(updated_docpath)) then
                print("failed to save updated musx " .. updated_docpath)
            end
            local docs = finale.FCDocuments()
            if finenv.UI():IsOnMac() or docs:LoadAll() > 1 then
                document:CloseCurrentDocumentAndWindow(false) -- rollback any edits
            end
            document:SwitchBack()
        else
            print("failed to open document " .. document_path)
        end
        os.remove(client.encode_with_client_codepage(copy_path))
    else
        print ("failed to copy mus file to " .. copy_path)
    end
end

local function process_document(path, file, extension)
    if extension == MUSICXML_EXTENSION or extension == MUSESTYLE_EXTENSION or extension == ENIGMAXML_EXTENSION then
        move_to_export_folder(path, file .. extension)
    elseif extension == MUS_EXTENSION then
        local attr = lfs.attributes(client.encode_with_client_codepage(path .. file .. MUSX_EXTENSION))
        if not attr or attr.mode ~= "file" then
            export_updated_document(path, file, extension)
        end
    elseif extension == MUSX_EXTENSION then
        export_updated_document(path, file, extension)
    end
end

function run_status_dialog(selected_directory, files_to_process)
    local dialog = mixin.FCXCustomLuaWindow()
        :SetTitle("Move Exports to Exports Folder")
    local current_y = 0
    -- processing folder
    dialog:CreateStatic(0, current_y + 2, "folder_label")
        :SetText("Folder:")
        :DoAutoResizeWidth(0)
    dialog:CreateStatic(0, current_y + 2, "folder")
        :SetText("")
        :SetWidth(400)
        :AssureNoHorizontalOverlap(dialog:GetControl("folder_label"), 5)
        :StretchToAlignWithRight()
    current_y = current_y + 20
    -- processing file
    dialog:CreateStatic(0, current_y + 2, "file_path_label")
        :SetText("File:")
        :DoAutoResizeWidth(0)
    dialog:CreateStatic(0, current_y + 2, "file_path")
        :SetText("")
        :SetWidth(300)
        :AssureNoHorizontalOverlap(dialog:GetControl("file_path_label"), 5)
        :HorizontallyAlignLeftWith(dialog:GetControl("folder"))
        :StretchToAlignWithRight()
    -- cancel
    dialog:CreateCancelButton("cancel")
    -- registrations
    dialog:RegisterInitWindow(function(self)
        self:SetTimer(TIMER_ID, 100) -- 100 milliseconds
    end)
    dialog:RegisterHandleTimer(function(self, timer)
        assert(timer == TIMER_ID, "incorrect timer id value " .. timer)
        if #files_to_process <= 0 then
            self:StopTimer(TIMER_ID)
            self:GetControl("folder"):SetText(selected_directory)
            self:GetControl("file_path"):SetText("(export complete)")
            self:GetControl("cancel"):SetText("Close")
            return
        end
        self:GetControl("folder"):SetText("..." .. files_to_process[1].path:sub(#selected_directory))
            :RedrawImmediate()
        self:GetControl("file_path"):SetText(files_to_process[1].file .. files_to_process[1].extension)
            :RedrawImmediate()
        process_document(files_to_process[1].path, files_to_process[1].file, files_to_process[1].extension)
        table.remove(files_to_process, 1)
    end)
    dialog:RegisterCloseWindow(function(self)
        self:StopTimer(TIMER_ID)
        if #files_to_process > 0 then
            print("processing aborted by user")
        end
        finenv.RetainLuaState = false
    end)
    dialog:RunModeless()
end

local FOLDER_SEP <const> = finenv.UI():IsOnMac() and "/" or "\\"
local SUBFOLDER_STRING <const> = FOLDER_SEP .. SUBFOLDER_NAME .. FOLDER_SEP

local files_to_process = {}

for path, filename in utils.eachfile(selected_folder, true) do
    if path:sub(-SUBFOLDER_STRING:len()) ~= SUBFOLDER_STRING then
        local _, file, extension = utils.split_file_path(filename)
        if extension == MUSX_EXTENSION or extension == MUS_EXTENSION or extension == ENIGMAXML_EXTENSION
                    or extension == MUSICXML_EXTENSION or extension == MUSESTYLE_EXTENSION then
            table.insert(files_to_process, {file = file, path = path, extension = extension})
        end
    end
end

if #files_to_process > 0 then
    run_status_dialog(selected_folder, files_to_process)
else
    finenv.UI():AlertInfo("No exported files found in " .. selected_folder, "")
end