function plugindef()
    finaleplugin.RequireDocument = false
    finaleplugin.NoStore = true
    finaleplugin.ExecuteExternalCode = true
    finaleplugin.ExecuteHttpsCalls = true
    finaleplugin.HandlesUndo = true
    finaleplugin.MinJWLuaVersion = 0.68
    finaleplugin.ExecuteHttpsCalls = true
    finaleplugin.Author = "Robert Patterson"
    finaleplugin.Copyright = "CC0 https://creativecommons.org/publicdomain/zero/1.0/"
    finaleplugin.Version = "1.0"
    finaleplugin.Date = "September 22, 2023"
    finaleplugin.CategoryTags = "Lyrics"
    finaleplugin.Notes = [[
        Uses the OpenAI online api as a chatbot. One reason you might use this instead
        of the free ChatGPT site is to be able to pose questions to GPT-4 without paying
        the monthly subscription.

        You must have a OpenAI account and internet connection. You will
        need your API Key, which can be obtained as follows:

        - Login to your OpenAI account at openai.com.
        - Select API and then click on Personal
        - You will see an option to create an API Key.
        - You must keep your API Key secure. Do not share it online.

        To configure your OpenAI account, enter your API Key in the prefix
        when adding the script to RGP Lua. If you want OpenAI to be available in
        any script, you can add your key to the System Prefix instead.

        Your prefix should include this line of code:

        ```
        openai_api_key = "<your secure api key>"
        ```

        It is important to enclose the API Key you got from OpenAI in quotes as shown
        above.

        The first time you use the script, RGP Lua will prompt you for permission
        to post data to the openai.com server. You can choose Allow Always to suppress
        that prompt in the future.

        The OpenAI service is not free, but each request is very
        light (using ChatGPT 3.5) and small jobs only cost fractions of a cent.
        Check the pricing at the OpenAI site.
    ]]
    return "OpenAI ChatBot...", "OpenAI ChatBot",
        "Post questions to OpenAI language models using your OpenAI account."
end

local mixin = require("library.mixin")
local openai = require("library.openai")

local osutils = require("luaosutils")
local https = osutils.internet

local models =
{
    ["GPT-3.5"] = "gpt-3.5-turbo",
    ["GPT-4 Turbo"] = "gpt-4",
    ["GPT-4o"] = "gpt-4o"
}


context = context or
{
    https_session = nil,
    messages = nil,
    message_count = 0
}

local function enable_disable(enable)
    global_dialog:GetControl("prompt"):SetEnable(enable)
    global_dialog:GetControl("go"):SetEnable(enable)
end

local function send_prompt()
    if not global_dialog then return end
    local temperature = 0.7 -- ToDo: make this configurable
    local model = finale.FCString()
    local dlg = global_dialog
    dlg:GetControl("model"):GetSelectedString(model)
    local prompt = finale.FCString()
    dlg:GetControl("prompt"):GetText(prompt)
    enable_disable(false)
    dlg:GetControl("response"):AppendText(finale.FCString(prompt.LuaString.."\n\n========================================>>>>\n\n"))
    if not context.messages then
        context.messages = {}
        table.insert(context.messages, {role = "system", content = "You are a helpful assistant."})
        context.message_count = 1
    end
    table.insert(context.messages, {role = "user", content = prompt.LuaString})
    context.message_count = context.message_count + 1
    context.https_session = openai.create_chat(models[model.LuaString], context.messages, temperature, function(success, result)
        if not context.https_session then return end
        context.https_session = nil
        enable_disable(true)
        if success then
            table.insert(context.messages, {role = result.choices[1].message.role, content = result.choices[1].message.content})
            context.message_count = context.message_count + 1
            result = result.choices[1].message.content
        else
            result = "ERROR: "..result
        end
        local response = dlg:GetControl("response")
        result = result .. "\n\n<<<<========================================\n\n"
        response:AppendText(finale.FCString(result))
        response:ScrollToBottom()
        response:RedrawImmediate()
        dlg:GetControl("prompt"):SelectAll()
    end)
end

local function create_dialog()
    local dlg = mixin.FCXCustomLuaWindow():SetTitle("OpenAI ChatBot")
    local current_y = 0
    local y_separator = 10
    local current_x = 0
    local x_separator = 10
    local button_height = 20
    local button_width = 80
    dlg:CreatePopup(current_x, current_y, "model")
        :SetWidth(90)
    for k, _ in pairsbykeys(models) do
        dlg:GetControl("model"):AddString(k)
    end
    dlg:GetControl("model"):SetSelectedItem(2) -- counting from zero: GPT-4o is the default.
    current_x = current_x + 90 + x_separator
    dlg:CreateButton(current_x, current_y)
        :SetText("New Chat")
        :SetWidth(90)
        :AddHandleCommand(function(control)
            context.https_session = https.cancel_session(context.https_session)
            context.messages = nil
            context.message_count = 0
            control:GetParent():GetControl("prompt"):SetText("")
            control:GetParent():GetControl("response"):SetText("")
            enable_disable(true)
        end)
    current_y = current_y + button_height + y_separator
    current_x = 0
    local chatbox_height = 275
    local chatbox_width = 800
    dlg:CreateTextEditor(current_x, current_y, "prompt")
        :SetWidth(chatbox_width)
        :SetHeight(chatbox_height)
        :SetFont(finale.FCFontInfo("Arial", 14))
        :SetUseRichText(false)
    current_y = current_y + chatbox_height + y_separator
    current_x = 0
    dlg:CreateButton(current_x, current_y, "copyall")
        :SetText("Copy")
        :SetWidth(button_width)
        :AddHandleCommand(function(control)
            local str = finale.FCString()
            dlg:GetControl("response"):GetText(str)
            finenv.UI():TextToClipboard(str.LuaString)
            dlg:CreateChildUI():AlertInfo("Response text copied to clipboard.", "Text Copied")
        end)
    current_x = current_x + button_width + x_separator
    dlg:CreateButton(current_x, current_y, "copylast")
        :SetText("Copy Last")
        :SetWidth(button_width)
        :AddHandleCommand(function(control)
            for i = context.message_count, 1, -1 do
                if context.messages[i].role == "assistant" then
                    finenv.UI():TextToClipboard(context.messages[i].content)
                    dlg:CreateChildUI():AlertInfo("Last response copied to clipboard.", "Text Copied")
                    return
                end
            end
            dlg:CreateChildUI():AlertError("No response found.", "Nothing Copied")
        end)
    current_y = current_y + button_height + y_separator
    current_x = 0
    dlg:CreateTextEditor(current_x, current_y, "response")
        :SetWidth(chatbox_width)
        :SetHeight(chatbox_height)
        :SetReadOnly(true)
        :SetFont(finale.FCFontInfo("Arial", 14))
        :SetUseRichText(false)
    dlg:CreateOkButton("go"):SetText("Go")
    dlg:RegisterHandleOkButtonPressed(send_prompt)
    dlg:CreateCancelButton():SetText("Close")
    dlg:RegisterCloseWindow(function()
        context.https_session = https.cancel_session(context.https_session)
        enable_disable(true)
    end)
    return dlg
end

local function openai_chat()
    if not global_dialog then
        global_dialog = create_dialog()
    end
    global_dialog:RunModeless()
end

openai_chat()
