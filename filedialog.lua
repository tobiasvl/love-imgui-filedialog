local nativefs = require("nativefs")

local dialog = {}
dialog.tmpDir = '.imguitmp'

function dialog.new(mode, ...)
    local args = {...}
    local fileCallback, cancelCallback, path, defaultFilename, saveFile
    if mode == 'open' then
        fileCallback = args[1]
        cancelCallback = args[2]
        path = args[3]
    elseif mode == 'save' then
        saveFile = args[1]
        defaultFilename = args[2]
        successCallback = args[3]
        cancelCallback = args[4]
        path = args[5]
    end

    local self = {}
    setmetatable(self, {__index=dialog})

    self.path = path or nativefs.getWorkingDirectory()
    self.files = {}
    self.fileCallback = fileCallback
    self.cancelCallback = cancelCallback
    self.saveFilename = 'untitled' or defaultFilename
    self.saveFile = saveFile
    self.view = 'list'
    self.mode = mode
    self.previewCanvas = nil
    self.previewImage = nil
    self.selectedTime = 0
    self.windowSizeSet = false
    self.columnWidthSet = false
    self.close = false
    self._pathbar = {}
    self._pathbar.viewButtonWidth = 0

    self:_updateFiles()

    return self
end

function dialog:draw()
    -- Create filedialog
    imgui.OpenPopup("File Chooser Dialog")

    -- Set dialog size
    if not self.defaultSizeSet then
        imgui.SetNextWindowSize(500, 300)
        self.defaultSizeSet = true
    end
    if imgui.BeginPopupModal("File Chooser Dialog") then
        self:_drawPathbar()
        if self.view == 'list' then
            self:_drawListView()
        elseif self.view == 'grid' then
            self._drawGridView()
        end
        self:_drawButtons()

        imgui.EndPopup()
    end

    if not self.close then
        return self
    end
end

function dialog:_drawPathbar()
    imgui.BeginChild("Pathbar", imgui.GetContentRegionMax()-self._pathbar.viewButtonWidth-10, imgui.GetItemsLineHeightWithSpacing())
        local dirs = {'/', unpack(self:_splitString(self.path, '/'))}
        for i, name in ipairs(dirs) do
            if imgui.Button(name) then
                self:_gotoParentDir(#dirs - i)
            end
            imgui.SameLine()
        end
    imgui.EndChild()
    imgui.SameLine(imgui.GetContentRegionMax()-self._pathbar.viewButtonWidth)
    if imgui.Button("View") then
        if self.view == 'grid' then
            self.view = 'list'
        else
            self.view = 'grid'
        end
    end
    self._pathbar.viewButtonWidth = imgui.GetItemRectSize()
    if self.mode == 'save' then
        _, self.saveFilename = imgui.InputText("File Name", self.saveFilename, 64)
    end
end

function dialog:_drawListView()
    -- Draw list view
    imgui.BeginChild(0, 0, -imgui.GetItemsLineHeightWithSpacing())
    imgui.Columns(3, nil, true)                                             -- Begin columns for file browser
    if not self.columnWidthSet then
        imgui.NextColumn()                                                  -- Move to Size column
        imgui.SetColumnOffset(-1, 170)                                      -- Set offset for Size column
        imgui.NextColumn()                                                  -- Move to Modified column
        imgui.SetColumnOffset(-1, 240)                                      -- Set offset for Modified column
        imgui.NextColumn()                                                  -- Return to Name column
    end
    imgui.Separator()

    -- Table Header
    imgui.Text("Name")
    imgui.NextColumn()
    imgui.Text("Size")
    imgui.NextColumn()
    imgui.Text("Modified")
    imgui.NextColumn()
    imgui.Separator()

    if not self.columnWidthSet then
        imgui.NextColumn()                                                  -- Move to Size column
        imgui.SetColumnOffset(-1, 170)                                      -- Set offset for Size column
        imgui.NextColumn()                                                  -- Move to Modified column
        imgui.SetColumnOffset(-1, 240)                                      -- Set offset for Modified column
        imgui.NextColumn()                                                  -- Return to Name column
        self.columnWidthSet = true
    end
    -- List files
    for i, file in ipairs(self.files) do
        -- Name
        if imgui.Selectable(file.name, self.selected == i, "DontClosePopups") then
            self:_fileClicked(i, file)
        end
        imgui.NextColumn()

        -- Size
        if file.attributes.type ~= 'directory' then
            local divisor
            local suffix

            if file.attributes.size > 1073741824 then
                divisor = 1073741824
                suffix = 'GB'
            elseif file.attributes.size > 1048576 then
                divisor = 1048576
                suffix = 'MB'
            elseif file.attributes.size > 1024 then
                divisor = 1024
                suffix = 'KB'
            else
                divisor = 1
                suffix = 'B'
            end

            local size = tostring(file.attributes.size/divisor)
            local str = string.format("%.1f", size)..suffix
            imgui.Text(str)
        end
        imgui.NextColumn()

        -- Modified Date
        local date = os.date("*t", file.attributes.modtime)
        if date then
            imgui.Text(date.year..'-'..date.month..'-'..date.day)
        end
        imgui.NextColumn()
    end

    imgui.Columns(1)
    imgui.EndChild()
end

function dialog:_drawGridView()
end

function dialog:_drawButtons()
    if imgui.Button("Close") then
        if self.cancelCallback then
            self.cancelCallback()
        end
        self.close = true
    end
    imgui.SameLine()
    if self.mode == 'open' then
        if imgui.Button("Open") then
            if self.fileCallback then
                self.fileCallback(self.files[self.selected].name)
            end
            self.close = true
        end
    elseif self.mode == 'save' then
        if imgui.Button('Save') then
            self:_saveFile()
            self.close = true
        end
    end
end

function dialog:_drawConfirm()
end

function dialog:_updateFiles()
    self.selected = nil
    self.files = {}
    for _, name in ipairs(nativefs.getDirectoryItems(self.path)) do
        local file = {}
        file.name = name
        file.attributes = nativefs.getInfo(self.path..'/'..name)
        if file.name ~= "." and file.name ~= ".." then
            table.insert(self.files, file)
        end
    end
    for a, b in pairs(self.files) do
        print(a, b.name)
    end
    table.sort(self.files, self._sortByName)
end

function dialog:_fileClicked(i, name)
    -- Detect double click
    if (self.selected == i) and (os.clock() - self.selectedTime) < 0.25 then
        if self.files[i].attributes.mode == 'directory' then
            self.path = self.path..'/'..self.files[i].name
            self.tmpPath = self.path
            self:_updateFiles()
        elseif self.files[i].attributes.mode == 'file' then
            if self.mode == 'open' then
                if self.fileCallback then
                    self.fileCallback(self.files[i].name)
                end
                self.close = true
            elseif self.mode == 'save' then
                print("ARE YOU SURE YOU WANT TO OVERWRITE???!?!??!??!??!")
            end
        end
    else
        self.selected = i
    end
    if self.files[i] and self.files[i].attributes.mode == 'file' then
        self.saveFilename = self.files[i].name
    end
    self.selectedTime = os.clock()
end

function dialog:_saveFile()
    local tmpFile = nativefs.getWorkingDirectory()..'/'..self.saveFile
    local newFile = self.path..'/'..self.saveFilename
    os.rename(tmpFile, newFile)
    print(tmpFile, newFile)
end

function dialog:_splitString(string, char)
    local strings = {}
    for substring in string.gmatch(string, '[^'..char..']+') do
        table.insert(strings, substring)
    end

    return strings
end

function dialog._sortByName(a, b)
    return string.lower(a.name) < string.lower(b.name)
end

function dialog:_gotoParentDir(n)
    for i=1, n do
        local index = self.path:find('/[^/]*$')
        if index ~= 1 then
            self.path = self.path:sub(0, index-1)
        else
            self.path = '/'
        end

        self.tmpPath = self.path
        self:_updateFiles()
    end
end

return dialog
