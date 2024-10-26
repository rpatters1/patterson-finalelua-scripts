function plugindef()
    finaleplugin.RequireDocument = false
    finaleplugin.RequireSelection = false
    finaleplugin.NoStore = true
    finaleplugin.ExecuteExternalCode = true
    finaleplugin.CategoryTags = "Document"
    finaleplugin.MinJWLuaVersion = 0.75
    return "Extract EnigmaXML...", "Extract EnigmaXML", "Extracts the EnigmaXML file within a .musx file."
end

local enigmaxml = require("library.enigmaxml")
local client = require("library.client")
local utils = require("library.utils")

local MUSX_EXTENSION <const> = ".musx"
local ENIGMAXML_EXTENSION <const> = ".enigmaxml"

local input_filepath = finale.FCString()
local output_filepath = finale.FCString()
local documents = finale.FCDocuments()
documents:LoadAll()
local document = documents:FindCurrent()
if document then
    document:GetPath(input_filepath)
    local path, name, _extension = utils.split_file_path(input_filepath.LuaString)
    local save_dialog = finale.FCFileSaveAsDialog(finenv.UI())
    save_dialog:SetWindowTitle(finale.FCString("Save EnigmaXML File as"))
    save_dialog:AddFilter(finale.FCString("*" .. ENIGMAXML_EXTENSION), finale.FCString("Enigma XML File"))
    save_dialog:SetInitFolder(finale.FCString(path))
    print(name)
    save_dialog:SetFileName(finale.FCString(name))
    save_dialog:AssureFileExtension(ENIGMAXML_EXTENSION)
    if not save_dialog:Execute() then
        return
    end
    save_dialog:GetFileName(output_filepath)
else
    local path_name = finale.FCString()
    path_name:SetMusicFolderPath()
    local open_dialog = finale.FCFileOpenDialog(finenv.UI())
    open_dialog:SetWindowTitle(finale.FCString("Select a MusicXML File:"))
    open_dialog:AddFilter(finale.FCString("*" .. MUSX_EXTENSION), finale.FCString("Finale File"))
    open_dialog:SetInitFolder(path_name)
    open_dialog:AssureFileExtension(MUSX_EXTENSION)
    if not open_dialog:Execute() then
        return
    end
    open_dialog:GetFileName(input_filepath)
    local path, name, _extension = utils.split_file_path(input_filepath.LuaString)
    output_filepath.LuaString = path .. name .. ENIGMAXML_EXTENSION
end

local os_input = client.encode_with_client_codepage(input_filepath.LuaString)
local buffer = enigmaxml.extract_enigmaxml(os_input)

local os_output = client.encode_with_client_codepage(output_filepath.LuaString)
local out_file <close> = io.open(os_output, "wb")
out_file:write(buffer)
out_file:close()

local output_name = client.encode_with_utf8_codepage(os_output)
finenv:UI():AlertInfo("Wrote EnigmaXML " .. output_name, "Success")
