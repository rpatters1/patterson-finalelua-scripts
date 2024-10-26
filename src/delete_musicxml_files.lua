function plugindef()
    finaleplugin.RequireDocument = false
end

local folder_dialog = finale.FCFolderBrowseDialog(finenv.UI())
local path_name = finale.FCString()
path_name:SetMusicFolderPath()
folder_dialog:SetWindowTitle(finale.FCString("Select folder in which to delete MusicXML files:"))
folder_dialog:SetFolderPath(path_name)
folder_dialog:SetUseFinaleAPI(finenv:UI():IsOnMac())
if not folder_dialog:Execute() then
    return false -- user cancelled
end
folder_dialog:GetFolderPath(path_name)

local MUSICXML_EXTENSION <const> = ".musicxml"

local MSG <const> = "This script deletes any file with extension '" .. MUSICXML_EXTENSION .. "' from "
                        .. path_name.LuaString .. " and its subdirectories."
if finenv:UI():AlertYesNo(MSG, "Continue?") ~= finale.YESRETURN then
    return false
end

local utils = require("library.utils")
local text = require("luaosutils").text

local files_deleted = 0

for path, file_name in utils.eachfile(path_name.LuaString, true) do
    local _, _, extension = utils.split_file_path(file_name)
    --if file_name == "FinaleMuseScoreSettingsExportLog.txt" then
    if extension == MUSICXML_EXTENSION then
        print("deleting ", path .. file_name)
        os.remove(text.convert_encoding(path .. file_name, text.get_utf8_codepage(), text.get_default_codepage()))
        files_deleted = files_deleted + 1
    end
end

print("deleted " .. files_deleted .. " files.")
return true
