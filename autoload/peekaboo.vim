" The MIT License (MIT)
"
" Copyright (c) 2015 Junegunn Choi
"
" Permission is hereby granted, free of charge, to any person obtaining a copy
" of this software and associated documentation files (the "Software"), to deal
" in the Software without restriction, including without limitation the rights
" to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
" copies of the Software, and to permit persons to whom the Software is
" furnished to do so, subject to the following conditions:
"
" The above copyright notice and this permission notice shall be included in
" all copies or substantial portions of the Software.
"
" THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
" IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
" FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
" AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
" LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
" OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
" THE SOFTWARE.

let s:cpo_save = &cpo
set cpo&vim

let s:peekaboo = 0

function! s:append_group(title, regs)
  call append(line('$'), a:title.':')
  for r in a:regs
    try
      if r == '%'     | let val = s:cur
      elseif r == '#' | let val = s:alt
      else            | let val = eval('@'.r)
      endif
      if empty(val)
        continue
      endif
      let s:regs[printf('%s', r)] = line('$')
      call append(line('$'), printf(' %s: %s', r, val))
    catch
    endtry
  endfor
  call append(line('$'), '')
endfunction

function! s:close()
  if s:peekaboo
    silent! execute 'bd' s:peekaboo
  endif
endfunction

function! s:init(mode)
  call s:close()
  let delay = get(g:, 'peekaboo_delay', 0)
  while delay > 0
    let delay -= 50
    let c = getchar(0)
    if c
      return nr2char(c)
    endif
    sleep 50m
  endwhile

  let [s:cur, s:alt] = [@%, @#]
  execute get(g:, 'peekaboo_window', 'vertical botright 30new')
  let s:peekaboo = bufnr('')
  setlocal nonumber buftype=nofile bufhidden=wipe nobuflisted noswapfile nowrap
         \ modifiable statusline=>\ Registers nocursorline nofoldenable
  setfiletype peekaboo
  augroup peekaboo
    autocmd!
    autocmd CursorMoved <buffer> bd
  augroup END

  let s:regs = {}
  call s:append_group('Special', ['"', '*', '+', '-'])
  call s:append_group('Read-only', a:mode ==# 'replay' ? ['.'] : ['.', '%', '#', '/'])
  call s:append_group('Numbered', range(0, 9))
  call s:append_group('Named', map(range(97, 97 + 25), 'nr2char(v:val)'))
  normal! "_dd
  return ''
endfunction

function! s:back(visualmode)
  wincmd p
  if a:visualmode
    normal! gv
  endif
  redraw
endfunction

function! s:feed(count, mode, reg, rest)
  let seq = a:count > 1 ? a:count : ''
  if a:mode ==# 'quote'
    if a:reg == '"' | let seq .= "\<Plug>(pkbq2)" . a:rest
    else            | let seq .= "\<Plug>(pkbq1)" . a:reg . a:rest
    endif
  elseif a:mode ==# 'ctrl-r'
    if a:reg == "\<c-r>" | let seq .= a:reg
    else                 | let seq .= "\<Plug>(pkbcr)" . a:reg
    endif
  else
    if a:reg == '@' | let seq .= "\<Plug>(pkbr2)" . a:rest
    else            | let seq .= "\<Plug>(pkbr1)" . a:reg . a:rest
    endif
  endif
  call feedkeys(seq)
endfunction

function! peekaboo#peek(count, mode, visualmode)
  let c = s:init(a:mode)
  if !empty(c)
    if a:visualmode
      normal! gv
    endif
    return s:feed(a:count, a:mode, c, '')
  endif
  call s:back(a:visualmode)

  let tl = &tabline
  let zoom = 0
  try
    while 1
      let reg = nr2char(getchar())
      if zoom
        tab close
        let &tabline = tl
        call s:back(a:visualmode)
      endif
      if reg != ' '
        break
      endif
      if !zoom
        wincmd p
        tab split
        set tabline=%#TabLineSel#>\ Registers
      endif
      let zoom = !zoom
      redraw
    endwhile

    let rest = ''
    if a:mode ==# 'quote' && has_key(s:regs, tolower(reg))
      wincmd p
      let line = s:regs[tolower(reg)]
      execute 'normal!' line.'G'
      execute 'syntax region peekabooSelected start=/\%'.line.'l\%5c/ end=/$/'
      setlocal cursorline
      call setline(line('.'), substitute(getline('.'), ' .', ' '.reg, ''))
      call s:back(a:visualmode)
      let rest = nr2char(getchar())
    endif

    call s:feed(a:count, a:mode, reg, rest)
  catch /^Vim:Interrupt$/
    return
  finally
    let &tabline = tl
    call s:close()
    redraw
  endtry
endfunction

nnoremap <Plug>(pkbq1) "
nnoremap <Plug>(pkbq2) ""
xnoremap <Plug>(pkbq1) "
xnoremap <Plug>(pkbq2) ""
nnoremap <Plug>(pkbr1) @
nnoremap <Plug>(pkbr2) @@
inoremap <Plug>(pkbcr) <c-r>

let &cpo = s:cpo_save
unlet s:cpo_save

