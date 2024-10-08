local M = {}
local selected_model = nil
local input_buf = nil
local output_buf = nil
local input_win = nil
local output_win = nil
local vim = _G.vim

local function draw_ascii_borders(bufnr, width, height, title)
	local border_lines = {}

	-- Top border with title
	table.insert(border_lines, "╭" .. string.rep("─", width - 2) .. "╮")
	table.insert(border_lines, "│ " .. title .. string.rep(" ", width - #title - 3) .. "│")

	-- Middle borders (empty space)
	for i = 1, height - 3 do
		table.insert(border_lines, "│" .. string.rep(" ", width - 2) .. "│")
	end

	-- Bottom border
	table.insert(border_lines, "╰" .. string.rep("─", width - 2) .. "╯")

	-- Set the border lines into the buffer
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, border_lines)
end

local function create_section(title, width, height, row, col)
	local bufnr = vim.api.nvim_create_buf(false, true)

	-- Draw the borders
	draw_ascii_borders(bufnr, width, height, title)

	-- Create a floating window with the buffer
	vim.api.nvim_open_win(bufnr, true, {
		relative = "editor",
		width = width,
		height = height,
		row = row,
		col = col,
		style = "minimal",
	})
end

-- Function to create the main window with separate input and output sections
local function create_main_window()
	-- create_section("Status", 30, 10, 0, 0)
	-- create_section("Files", 30, 10, 11, 0)

	-- Create input buffer and window
	if not input_buf then
		input_buf = vim.api.nvim_create_buf(false, true) -- Create a new buffer for input
		vim.api.nvim_buf_set_option(input_buf, "buflisted", false)
		vim.api.nvim_buf_set_option(input_buf, "bufhidden", "wipe")
	end

	-- Create output buffer and window
	if not output_buf then
		output_buf = vim.api.nvim_create_buf(false, true) -- Create a new buffer for output
		vim.api.nvim_buf_set_option(output_buf, "buflisted", false)
		vim.api.nvim_buf_set_option(output_buf, "bufhidden", "wipe")
	end

	local width = vim.api.nvim_get_option("columns")
	local height = vim.api.nvim_get_option("lines")
	local input_height = 5
	local output_height = height - input_height - 7 -- Adjusted to add an extra gap

	-- Create input window
	input_win = vim.api.nvim_open_win(input_buf, true, {
		relative = "editor",
		width = math.floor(width * 0.9),
		height = input_height,
		col = math.floor(width * 0.05),
		row = math.floor(height * 0.05),
		anchor = "NW",
		style = "minimal",
		border = "rounded",
	})
	vim.api.nvim_buf_set_option(input_buf, "nu", true)
	vim.api.nvim_buf_set_option(input_buf, "rnu", true)

	-- Create output window
	output_win = vim.api.nvim_open_win(output_buf, true, {
		relative = "editor",
		width = math.floor(width * 0.9),
		height = output_height - 4,
		col = math.floor(width * 0.05),
		row = math.floor(height * 0.05) + input_height + 2, -- Added an extra gap between input and output
		anchor = "NW",
		style = "minimal",
		border = "rounded",
	})

	-- Set output buffer as non-modifiable
	vim.api.nvim_buf_set_option(output_buf, "modifiable", false)

	-- Set up the Shift+Enter key mapping to trigger the query
	vim.api.nvim_buf_set_keymap(
		input_buf,
		"i",
		"<S-CR>",
		"<cmd>lua require('ollama').send_query()<CR>",
		{ noremap = true, silent = true }
	)

	-- Set up the 'q' keybinding to close the plugin in normal mode for both input and output windows
	vim.api.nvim_buf_set_keymap(
		input_buf,
		"n",
		"q",
		"<cmd>lua require('ollama').toggle()<CR>",
		{ noremap = true, silent = true }
	)
	vim.api.nvim_buf_set_keymap(
		output_buf,
		"n",
		"q",
		"<cmd>lua require('ollama').toggle()<CR>",
		{ noremap = true, silent = true }
	)

	-- Set up navigation with `[` and `]`
	vim.api.nvim_buf_set_keymap(
		input_buf,
		"n",
		"[",
		"<cmd>lua require('ollama').focus_output()<CR>",
		{ noremap = true, silent = true }
	)
	vim.api.nvim_buf_set_keymap(
		output_buf,
		"n",
		"]",
		"<cmd>lua require('ollama').focus_input()<CR>",
		{ noremap = true, silent = true }
	)
end

-- Function to display output in the bottom section
local function display_output(result)
	-- Make the output buffer modifiable temporarily
	vim.api.nvim_buf_set_option(output_buf, "modifiable", true)

	-- Clear the previous content and insert the new result
	vim.api.nvim_buf_set_lines(output_buf, 0, -1, false, vim.split(result, "\n"))

	-- Set syntax highlighting and make the buffer non-modifiable again
	vim.api.nvim_buf_set_option(output_buf, "filetype", "markdown")
	vim.api.nvim_buf_set_option(output_buf, "modifiable", false)

	vim.api.nvim_buf_set_option(output_buf, "rnu", true)
	vim.api.nvim_buf_set_option(output_buf, "nu", true)

	-- Move cursor back to input window, reset the prompt, and clear the input line
	vim.api.nvim_set_current_win(input_win)
	vim.cmd("startinsert")
end

-- Function to clean output from unwanted characters
local function clean_output(output)
	-- Remove ANSI escape sequences
	output = output:gsub("\27%[%d+;%d+;%d+;%d+;%d+;%d+m", "") -- Remove specific sequences
	output = output:gsub("\27%[%d+;%d+m", "")                -- Remove other sequences
	output = output:gsub("\27%[%d+K", "")                    -- Remove clear line sequences
	output = output:gsub("\27%[%d+G", "")                    -- Remove cursor move sequences
	output = output:gsub("\27%[%?25[lh]", "")                -- Remove cursor visibility sequences
	return output
end

-- Function to send the query to the ollama model asynchronously
function M.send_query()
	if not selected_model then
		vim.notify("No model selected.", vim.log.levels.WARN)
		return
	end

	-- Get all lines of the query text from the input buffer
	local query_lines = vim.api.nvim_buf_get_lines(input_buf, 0, -1, false)

	-- Concatenate all lines with proper escaping for the shell
	local query = table.concat(vim.tbl_map(vim.fn.shellescape, query_lines), " ")

	-- Display a processing notification
	vim.notify("Processing request...", vim.log.levels.INFO)

	-- Run the Ollama command asynchronously
	vim.fn.jobstart({ "bash", "-c", "ollama run " .. selected_model .. ' <<< "' .. query .. '"' }, {
		stdout_buffered = true,
		on_stdout = function(_, data)
			if data then
				local result = table.concat(data, "\n")
				result = clean_output(result)
				-- Display the output in the output buffer
				display_output(result)
			end
		end,
		on_stderr = function(_, data)
			-- Ignore stderr errors to prevent showing unwanted messages
		end,
		on_exit = function(_, code)
			if code ~= 0 then
				vim.notify("Failed to run query.", vim.log.levels.ERROR)
			end
		end,
	})

	-- Clear the input buffer and reset the prompt
	vim.api.nvim_buf_set_lines(input_buf, 0, -1, false, {})
	vim.cmd("startinsert")
end

-- Function to focus the input window
function M.focus_input()
	vim.api.nvim_set_current_win(input_win)
	vim.cmd("startinsert")
end

-- Function to focus the output window
function M.focus_output()
	vim.api.nvim_set_current_win(output_win)
	vim.api.nvim_win_set_cursor(output_win, { 1, 0 }) -- Move cursor to the first line, first character
end

-- Function to select a model using telescope.nvim
function M.select_model()
	local handle = io.popen("ollama ps")
	local result = handle:read("*a")
	handle:close()

	local models = {}
	for line in result:gmatch("[^\r\n]+") do
		if line:match("^%S") then
			local model_name = line:match("^(%S+)")
			if model_name ~= "NAME" then
				table.insert(models, model_name)
			end
		end
	end

	if #models == 0 then
		handle = io.popen("ollama list")
		result = handle:read("*a")
		handle:close()

		for line in result:gmatch("[^\r\n]+") do
			if line:match("^%S") then
				local model_name = line:match("^(%S+)")
				if model_name ~= "NAME" then
					table.insert(models, model_name)
				end
			end
		end

		if #models == 0 then
			vim.notify("No models available locally.", vim.log.levels.ERROR)
			return
		end
	end

	require("telescope.pickers")
			.new({}, {
				prompt_title = "Select Ollama Model",
				finder = require("telescope.finders").new_table({
					results = models,
				}),
				sorter = require("telescope.config").values.generic_sorter({}),
				attach_mappings = function(_, map)
					map("i", "<CR>", function(prompt_bufnr)
						local selection = require("telescope.actions.state").get_selected_entry(prompt_bufnr)
						selected_model = selection[1]
						vim.notify("Selected model: " .. selected_model, vim.log.levels.INFO)
						require("telescope.actions").close(prompt_bufnr)
						create_main_window()

						-- Move cursor to the input window after selecting the model
						vim.api.nvim_set_current_win(input_win)
						vim.cmd("startinsert")
					end)
					return true
				end,
			})
			:find()
end

-- Command to start the interaction
function M.start()
	M.select_model()
end

-- Command to toggle the main window
function M.toggle()
	if input_buf and vim.api.nvim_buf_is_loaded(input_buf) then
		if vim.api.nvim_win_is_valid(input_win) then
			vim.api.nvim_win_close(input_win, true)
		end
		if vim.api.nvim_win_is_valid(output_win) then
			vim.api.nvim_win_close(output_win, true)
		end
		input_buf = nil
		output_buf = nil
	else
		M.start()
	end
end

return M
