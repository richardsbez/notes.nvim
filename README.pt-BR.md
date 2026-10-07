# notes.nvim

Gerenciador de notas rápidas para o Neovim, inspirado em apps de notas do GNOME
como o [Folio](https://github.com/toolstack/Folio): **cadernos** à esquerda,
**lista de notas** (título + data) no meio e **editor** à direita.

As notas são arquivos Markdown comuns: dá para versionar com git, sincronizar com
Syncthing ou abrir em qualquer outro editor.

<!-- TODO: adicionar print, ex.: docs/screenshot.png -->

## Recursos

- Layout em três painéis numa janela flutuante centralizada
- Autosave, e nunca cria notas vazias
- Cadernos são apenas pastas
- Busca no conteúdo de todos os cadernos
- Lixeira com restauração e exclusão definitiva
- Captura rápida: `:QuickNote` abre uma nota nova pronta para digitar
- **Modo popup** opcional: roda numa janela de terminal própria, flutuando sobre
  todo o desktop
- Sem dependências

## Requisitos

- Neovim **0.9+**

## Instalação

Com [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "SEU_USUARIO/notes.nvim",
  cmd = { "Notes", "QuickNote", "NotesApp" },
  keys = {
    { "<leader>on", "<cmd>Notes<cr>",     desc = "Abrir notas" },
    { "<leader>oq", "<cmd>QuickNote<cr>", desc = "Nota rápida" },
  },
  opts = {
    dir = "~/notes",
  },
}
```

Sem gerenciador de plugins: copie `lua/notes/init.lua` para
`~/.config/nvim/lua/notes/init.lua` e adicione ao seu `init.lua`:

```lua
require("notes").setup({ dir = "~/notes" })
```

## Configuração

Veja os valores padrão na seção *Configuration* do [README em inglês](README.md#configuration).
Os mais úteis: `dir` (onde ficam as notas), `width` e `height` (frações da tela
até 1, ou colunas/linhas) e `border_hl` (cor da moldura).

## Uso

| Comando      | O que faz                                                            |
| ------------ | -------------------------------------------------------------------- |
| `:Notes`     | Abre/fecha a janela flutuante                                        |
| `:QuickNote` | Abre a janela e começa uma nota nova em modo de inserção             |
| `:NotesApp`  | Ocupa a janela inteira do terminal; fechar sai do Neovim (modo popup) |

Teclas dentro da janela:

| Tecla               | Onde               | Ação                                           |
| ------------------- | ------------------ | ---------------------------------------------- |
| `<Tab>` / `<S-Tab>` | cadernos, lista    | Alterna entre painéis                          |
| `<S-Tab>`           | editor (normal)    | Volta para a lista                             |
| `<CR>`              | cadernos, lista    | Abre o caderno / nota                          |
| `j` / `k`           | lista              | Próxima / anterior                             |
| `n`                 | cadernos, lista    | Nova nota                                      |
| `a`                 | cadernos           | Novo caderno                                   |
| `/`                 | lista              | Busca em todas as notas (`<Esc>` limpa)        |
| `d`                 | lista              | Move para a lixeira (apaga de vez se já nela)  |
| `r`                 | lista              | Restaura da lixeira                            |
| `q`                 | cadernos, lista    | Fecha                                          |

## Onde ficam as notas?

Em `~/notes`: cada caderno é uma pasta, cada nota é um arquivo `.md` (nome com
data e hora) e a lixeira é `~/notes/.trash`.

## Modo popup

O Neovim só desenha dentro do próprio terminal. Para ter uma janela flutuando no
meio da **tela inteira**, rode-o numa janela de terminal dedicada com
`nvim +NotesApp`. O script `bin/notes-popup` faz isso (kitty, ghostty, alacritty,
wezterm, foot ou gnome-terminal) usando a classe `notes-popup`:

```bash
install -Dm755 bin/notes-popup ~/.local/bin/notes-popup
```

Depois configure o seu gerenciador de janelas para deixar essa classe flutuante e
centralizada. Há exemplos para Hyprland em [`examples/`](examples/).

## Licença

[MIT](LICENSE)
