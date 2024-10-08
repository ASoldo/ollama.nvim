![image](https://github.com/user-attachments/assets/5e2df8d6-9842-4d89-a1ef-a4a2e3f684c5)
![image](https://github.com/user-attachments/assets/cf04454f-66fd-46ef-bf75-785cb654e565)

# ollama.nvim

`ollama.nvim` is a Neovim plugin that allows users to interact with the [Ollama](https://ollama.com/) language model directly from within Neovim. This plugin provides a simple interface for sending queries to a pre-configured model and displaying the output within the editor.

## Requirements

Before using this plugin, ensure you have the following installed:

1. **Ollama**: Download and install Ollama from [Ollama's official website](https://ollama.com/).

   - Follow the instructions on the website to install it on your system.
   - Once installed, you need to create or download a model using a `Modelfile` or a pre-built model.
   - You can run the model with the following command:
     ```sh
     ollama run model-name
     ```
     Replace `model-name` with the name of your model.

2. **Neovim**: Ensure that you have Neovim installed with Lua support (Neovim 0.5 or later).

## Installation

You can install `ollama.nvim` using the [Lazy.nvim](https://github.com/folke/lazy.nvim) plugin manager. Add the following to your `ollama.lua` configuration:

```lua
return {
  "ASoldo/ollama.nvim",
}
```

After adding the plugin, sync your plugin manager to install it.

## Usage

Once ollama.nvim is installed, you can map a key to invoke the plugin or call it directly from the Neovim command line.

## Key Mapping

Add the following to your Neovim configuration to map a key (e.g., <Leader>bo) to open the Ollama interface:

```lua
vim.api.nvim_set_keymap("n", "<Leader>bo", [[<cmd>lua require("ollama").start()<CR>]], { noremap = true, silent = true, desc = "Open Ollama" })
```

or

```lua
mappings = {
  n = {
    ["<Leader>bo"] = { function() require("ollama").start() end, desc = "Open Ollama", noremap = true, silent = true },
  },
},
```

This mapping allows you to press <Leader>bo in normal mode to start interacting with the Ollama model.

## Direct Command

Alternatively, you can invoke the plugin directly from the Neovim command line:

```lua
:lua require("ollama").start()
```

This command will prompt you for input and then display the output generated by the Ollama model.

## Example Workflow

Start the Plugin: Use the key mapping or the direct command to start the Ollama plugin in Neovim.

Enter Your Query: After invoking the plugin, a prompt will appear where you can type your query. Once you are done with typing and still in `Insert mode` press `Shift+Enter` to confirm and send the query.

View the Output: The response from the Ollama model will be displayed in a floating window within Neovim.

This plugin makes it easy to interact with powerful language models directly from your editor, streamlining your workflow and enhancing your productivity.
