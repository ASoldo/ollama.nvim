local M = {}

-- Function to create the input window
local function create_input_window()
	local buf = vim.api.nvim_create_buf(false, true) -- create a new empty buffer
	local width = vim.api.nvim_get_option("columns")
	local height = vim.api.nvim_get_option("lines")
	local win_height = 1
	local win_width = math.floor(width * 0.8)

	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = win_width,
		height = win_height,
		col = math.floor((width - win_width) / 2),
		row = math.floor(height / 2),
		anchor = "NW",
		style = "minimal",
		border = "rounded",
	})

	vim.api.nvim_buf_set_option(buf, "buftype", "prompt")
	vim.fn.prompt_setprompt(buf, "Query: ")

	vim.cmd("startinsert") -- start in insert mode

	-- Capture the input when Enter is pressed
	vim.api.nvim_buf_set_keymap(
		buf,
		"i",
		"<CR>",
		"<cmd>lua require('ollama').send_query()<CR>",
		{ noremap = true, silent = true }
	)

	M.input_win = win
	M.input_buf = buf
end

-- Function to display the output window
local function display_output(result)
	local output_buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(output_buf, 0, -1, false, vim.split(result, "\n"))

	local width = vim.api.nvim_get_option("columns")
	local height = vim.api.nvim_get_option("lines")
	local win_height = math.floor(height * 0.3)
	local win_width = math.floor(width * 0.8)

	local output_win = vim.api.nvim_open_win(output_buf, true, {
		relative = "editor",
		width = win_width,
		height = win_height,
		col = math.floor((width - win_width) / 2),
		row = math.floor((height - win_height) / 2),
		anchor = "NW",
		style = "minimal",
		border = "rounded",
	})

	vim.api.nvim_buf_set_option(output_buf, "modifiable", false)
end

-- Function to send the query to the ollama model
function M.send_query()
	local query = vim.fn.getline("."):sub(8) -- get the query text, removing the "Query: " prompt

	-- Close the input window
	vim.api.nvim_win_close(M.input_win, true)

	-- Move cursor away to avoid leaving a cursor line behind
	vim.cmd("normal! G")

	-- Run the ollama command and capture the output
	local handle = io.popen('ollama run jarvis <<< "' .. query .. '"')
	local result = handle:read("*a")
	handle:close()

	-- Display the output in a new floating window
	display_output(result)
end

-- Command to start the interaction
function M.start()
	create_input_window()
end

return M
