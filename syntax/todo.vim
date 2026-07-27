" File:        todo.txt.vim
" Description: Todo.txt syntax settings
" Author:      Leandro Freitas <freitass@gmail.com>
" License:     Vim license
" Website:     http://github.com/freitass/todo.txt-vim
" Version:     0.3

if exists("b:current_syntax")
    finish
endif

syntax  match  TodoDone       '^[xX]\s.\+$'
syntax  match  TodoPriorityA  '^([aA])\s.\+$'             contains=TodoDate,TodoProject,TodoContext
syntax  match  TodoPriorityB  '^([bB])\s.\+$'             contains=TodoDate,TodoProject,TodoContext
syntax  match  TodoPriorityC  '^([cC])\s.\+$'             contains=TodoDate,TodoProject,TodoContext
for s:nr in range(char2nr('d'), char2nr('z'))
    execute printf("syntax match TodoPriority%s '^([%s%s])\\s.\\+$' contains=TodoDate,TodoProject,TodoContext",
        \ toupper(nr2char(s:nr)), nr2char(s:nr), toupper(nr2char(s:nr)))
endfor

" Defined after the priority rules so it overrides their colours, but
" completed tasks are excluded so a done wf:1 line still reads as done.
syntax  match  TodoWaitingFor '^\%([xX]\s\)\@!.*\%(\s\|^\)wf:1\%(\s\|$\).*$'
syntax  match  TodoDate       '\d\{2,4\}-\d\{2\}-\d\{2\}' contains=NONE
syntax  match  TodoProject    '\(^\|\W\)+[^[:blank:]]\+'  contains=NONE
syntax  match  TodoContext    '\(^\|\W\)@[^[:blank:]]\+'  contains=NONE

" Priority colours for E-Z might be defined by the user
highlight  default  link  TodoDone       Comment
highlight  default  link  TodoWaitingFor  DiagnosticWarn
highlight  default  link  TodoPriorityA  Constant
highlight  default  link  TodoPriorityB  Statement
highlight  default  link  TodoPriorityC  Identifier
" (D) is stamped on blocked tasks by lua/todotxt/dependency.lua, so it
" gets a default colour to stay distinguishable once wf: flips to 0.
highlight  default  link  TodoPriorityD  DiagnosticHint
highlight  default  link  TodoDate       Type
highlight  default  link  TodoProject    Special
highlight  default  link  TodoContext    String

let b:current_syntax = "todo"
