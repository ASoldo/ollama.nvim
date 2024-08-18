local M = {}
local selected_model = nil
local input_buf = nil
local output_buf = nil
local input_win = nil
local output_win = nil
local vim = _G.vim

-- Function to create the main window with separate input and output sections
local function create_main_window()
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
	local input_height = 1
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

	vim.api.nvim_buf_set_option(input_buf, "buftype", "prompt")
	vim.fn.prompt_setprompt(input_buf, "Query: ")
	vim.cmd("startinsert")

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

	-- Set up the Enter key mapping to trigger the query
	vim.api.nvim_buf_set_keymap(
		input_buf,
		"i",
		"<CR>",
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
	vim.api.nvim_buf_set_lines(input_buf, 0, -1, false, { "Query: " }) -- Reset prompt
	vim.cmd("startinsert")
end

-- Function to send the query to the ollama model
function M.send_query()
	if not selected_model then
		vim.notify("No model selected.", vim.log.levels.WARN)
		return
	end

	-- Get the first line of the query text, removing the "Query: " prompt
	local query_lines = vim.api.nvim_buf_get_lines(input_buf, 0, -1, false)
	local query = table.concat(query_lines, " "):sub(8) -- Combine lines and extract the actual query

	-- Run the Ollama command and capture the output
	local handle = io.popen("ollama run " .. selected_model .. ' <<< "' .. query .. '"')
	local result = handle:read("*a")
	handle:close()

	-- Display the output in the output buffer
	display_output(result)

	-- Clear the input buffer and reset the prompt
	vim.api.nvim_buf_set_lines(input_buf, 0, -1, false, { "Query: " })
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
