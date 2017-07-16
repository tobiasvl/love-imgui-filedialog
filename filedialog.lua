local lfs = require("lfs")

local Filedialog = {}

function Filedialog.new(path, fileCallback, cancelCallback)
    local self = {}
    setmetatable(self, {__index=Filedialog})

    self.path = path or lfs.currentdir()
    self.tmpPath = self.path
    self:updateFiles()
    self.fileCallback = fileCallback
    self.cancelCallback = cancelCallback
    self.columnWidthSet = false
    self.selectedTime = 0
    self.close = false

    return self
end

function Filedialog:updateFiles()
    self.files = {}
    for name in lfs.dir(self.path) do
        local file = {}
        file.name = name
        file.attributes = lfs.attributes(self.path..'/'..name)
        if file.name ~= "." and file.name ~= ".." then
            table.insert(self.files, file)
        end
    end
end

function Filedialog:draw()
    -- Display file dialog
    imgui.OpenPopup("File Chooser Dialog")

    -- Set dialog size
    imgui.SetNextWindowSize(360, 300, "FirstUseEver")
    if imgui.BeginPopupModal("File Chooser Dialog") then
        local pathChange
        pathChange, self.tmpPath = imgui.InputText("", self.tmpPath, 64, "EnterReturnsTrue")
        if pathChange then
            self.path = self.tmpPath
            self:updateFiles()
            self.selected = nil
        end
        imgui.SameLine()
        if imgui.Button("..") then
            local index = self.path:find('/[^/]*$')
            if index ~= 1 then
                self.path = self.path:sub(0, index-1)
                self.tmpPath = self.path
                self:updateFiles()
            else
                self.path = '/'
                self.tmpPath = self.path
                self:updateFiles()
            end
        end
        if imgui.IsItemHovered() then
            imgui.BeginTooltip()
            imgui.Text("Move up one directory")
            imgui.EndTooltip()
        end
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

                -- Detect double click
                if (self.selected == i) and (os.clock() - self.selectedTime) < 0.15 then
                    if self.files[i].attributes.mode == 'directory' then
                        self.path = self.path..'/'..self.files[i].name
                        self.tmpPath = self.path
                        self:updateFiles()
                    elseif self.files[i].attributes.mode == 'file' then
                        self.fileCallback(self.files[i])
                        self.close = true
                    end
                end
                self.selectedTime = os.clock()
                self.selected = i
            end
            imgui.NextColumn()

            -- Size
            if file.attributes.mode ~= 'directory' then
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
            local date = os.date("*t", file.attributes.modification)
            imgui.Text(date.year..'-'..date.month..'-'..date.day)
            imgui.NextColumn()

        end

        imgui.Columns(1)
        imgui.Separator()
        imgui.EndChild()

        if imgui.Button("Close") then
            self.cancelCallback()
            self.close = true
        end
        imgui.SameLine()
        if imgui.Button("Open") then
            self.fileCallback(self.files[self.selected])
            self.close = true
        end
        imgui.EndPopup()

        if self.close then
            return nil
        end
    end

    return self
end

return Filedialog
