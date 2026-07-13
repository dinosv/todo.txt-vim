" File:        todo.txt.vim
" Description: Todo.txt filetype detection
" Author:      Leandro Freitas <freitass@gmail.com>
" License:     Vim license
" Website:     http://github.com/freitass/todo.txt-vim
" Version:     0.4

" Save context {{{1
let s:save_cpo = &cpo
set cpo&vim

" General options {{{1
" Some options lose their values when window changes. They will be set every
" time this script is invocated, which is whenever a file of this type is
" created or edited.
setlocal textwidth=0
setlocal wrapmargin=0

" Mappings {{{1
" Change priority {{{2
nnoremap <script> <silent> <buffer> <localleader>j :call todo#txt#prioritize_increase()<CR>
vnoremap <script> <silent> <buffer> <localleader>j :call todo#txt#prioritize_increase()<CR>
nnoremap <script> <silent> <buffer> <localleader>k :call todo#txt#prioritize_decrease()<CR>
vnoremap <script> <silent> <buffer> <localleader>k :call todo#txt#prioritize_decrease()<CR>
nnoremap <script> <silent> <buffer> <localleader>a :call todo#txt#prioritize_add('A')<CR>
vnoremap <script> <silent> <buffer> <localleader>a :call todo#txt#prioritize_add('A')<CR>
nnoremap <script> <silent> <buffer> <localleader>b :call todo#txt#prioritize_add('B')<CR>
vnoremap <script> <silent> <buffer> <localleader>b :call todo#txt#prioritize_add('B')<CR>
nnoremap <script> <silent> <buffer> <localleader>c :call todo#txt#prioritize_add('C')<CR>
vnoremap <script> <silent> <buffer> <localleader>c :call todo#txt#prioritize_add('C')<CR>

" Insert date {{{2
inoremap <script> <silent> <buffer> date<Tab> <C-R>=strftime("%Y-%m-%d")<CR>
nnoremap <script> <silent> <buffer> <localleader>d :call todo#txt#replace_date()<CR>
vnoremap <script> <silent> <buffer> <localleader>d :call todo#txt#replace_date()<CR>

" Remove completed {{{2
nnoremap <script> <silent> <buffer> <localleader>D :call todo#txt#remove_completed()<CR>

" Sorting, folding, mark-done, and mark-all-done are provided by
" ftplugin/todo.lua, which only Neovim >= 0.7 sources. Warn instead of
" silently dropping those features elsewhere.
if !has('nvim-0.7')
    echohl WarningMsg
    echomsg 'todo.txt-vim (nvim branch): sorting, folding and mark-done require Neovim >= 0.7'
    echohl None
endif

" Restore context {{{1
let &cpo = s:save_cpo
" Modeline {{{1
" vim: ts=8 sw=4 sts=4 et foldenable foldmethod=marker foldcolumn=1
