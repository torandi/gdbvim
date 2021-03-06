" Vim global plugin for interface to gdb.
" Last Modified: 2005-10-27 20:28:22
" Current Maintainer: Edward L. Fox <edyfox@gmail.com>
" Maintainer: Tomas Zellerin, <zellerin@volny.cz>

" You may want check http://www.volny.cz/zellerin/gdbvim/ for newer version of
" this and accompanying files, gdbvim and gdbvim.txt
"
" Feedback welcome.
"
" See :help gdbvim.txt for documentation

let s:BpSet = {}

" Prevent multiple loading, allow commenting it out
if exists("loaded_gdbvim")
        finish
endif

" If you dont have signs and clientserver, complain.
function Gdb_interf_init(fifo_name, pwd)
  echo "Can not use gdbvim plugin - your vim must have +signs and +clientserver features"
endfunction

if !(has("clientserver") && has("signs"))
  finish
endif

let loaded_gdbvim = 1
let s:having_partner=0

" This used to be in Gdb_interf_init, but older vims crashed on it
" highlight DebugBreak cterm=bold
" highlight DebugStop guibg=lightgreen guifg=white ctermbg=lightgreen ctermfg=white
sign define breakpoint linehl=DebugBreak text=##
sign define current linehl=DebugStop text=>>

function! ClearBreakpoints()
	for val in values(s:BpSet)
        silent call Gdb_command("clear ".val)
	endfor
	s:BpSet = {}
endfunction

" Get ready for communication
function! Gdb_interf_init(fifo_name, pwd)

  if s:having_partner " sanity check
    echo "Oops, one communication is already running"
    return
  endif
  let s:having_partner=1

  let s:fifo_name = a:fifo_name " Make use of parameters
  execute "cd ". a:pwd

  call s:Gdb_shortcuts()
  let g:loaded_gdbvim_mappings=1

  if !exists(":Gdb")
    command -nargs=+ Gdb        :call Gdb_command(<q-args>, v:count)
  endif

	echo 'GDB Connected'
endfunction

function Gdb_interf_close()
    call s:DeleteMenu()
    redir! > .gdbvim_breakpoints
    silent call s:DumpBreakpoints()
    redir END
    sign unplace *
    let s:BpSet = {}
    let s:having_partner=0
	echo 'GDB Connection Closed'
endfunction

function Gdb_Bpt(id, file, linenum)
        if !bufexists(a:file)
                execute "bad ".a:file
        endif
        execute "sign unplace ". a:id
        execute "sign place " .  a:id ." name=breakpoint line=".a:linenum." file=".a:file
		let s:BpSet[a:id] = fnamemodify(a:file, ":p") . ":" . a:linenum
		echo "Set breakpoint at " . a:file . ":" . a:linenum
endfunction

function Gdb_NoBpt(id)
        execute "sign unplace ". a:id
		let entry = remove(s:BpSet,a:id)
		echo "Removed breakpoint from " . entry
endfunction

function Gdb_CurrFileLine(file, line)
        if !bufexists(a:file)
                if !filereadable(a:file)
                        return
                endif
                execute "e ".a:file
        else
        execute "b ".a:file
        endif
        let s:file=a:file
        execute "sign unplace ". 3
        execute "sign place " .  3 ." name=current line=".a:line." file=".a:file
        execute a:line
        :silent! foldopen!
endf

function Gdb_NoCurrLine()
        execute "sign unplace ". 3
endfunction

noremap <unique> <script> <Plug>SetBreakpoint :call <SID>SetBreakpoint()<CR>

function Gdb_command(cmd, ...)
  if match (a:cmd, '^\s*$') != -1
    return
  endif
  let suff=""
  if 0<a:0 && a:1!=0
    let suff=" ".a:1
  endif
  silent exec ":redir >>".s:fifo_name ."|echon \"".a:cmd.suff."\n\"|redir END "
endfun

" Toggle breakpoints
function Gdb_togglebreak(name, line)
	let needle = fnamemodify(a:name, ":p") . ":" . a:line
	let found=0
	for [key,value] in items(s:BpSet)
		if value == needle
			let found=1
			break
		endif
	endfor
    if found == 1
        silent call Gdb_command("clear ".a:name.":".a:line)
    else
        silent call Gdb_command("break ".a:name.":".a:line)
    endif
endfun

" Init the menu
function s:InitMenu()
    nmenu Gdb.Command :Gdb

    nmenu Gdb.Debug.Run<tab><C-F5>      :Gdb run<CR>
    nmenu Gdb.Debug.Step<tab><F11>       :Gdb step<CR>
    nmenu Gdb.Debug.Next<tab><F10>       :Gdb next<CR>
    nmenu Gdb.Debug.Finish<tab><F12>     :Gdb finish<CR>
    nmenu Gdb.Debug.Continue<tab><F5>   :Gdb cont<CR>
    nmenu Gdb.Debug.Stop                :Gdb quit<CR>

    vmenu Gdb.Watch.Variable<tab><C-P>  "gy:Gdb print <C-R>g<CR>
    nmenu Gdb.Watch.Variable<tab><C-P>  :call Gdb_command("print ".expand("<cword>"))<CR>
    nmenu Gdb.Watch.Call\ stacks<tab><F8>        :Gdb bt<CR>

    nmenu Gdb.Breakpoints.Toggle\ break<tab><F9>            :call Gdb_togglebreak(bufname("%"), line("."))<CR>
    nmenu Gdb.Breakpoints.Clear\ all\ breakpoints           :call ClearBreakpoints()<CR>
endfunction

" Delete the menu
function s:DeleteMenu()
    aunmenu Gdb
endfunction

" Mappings are dependant on Leader at time of loading the macro.
function s:Gdb_shortcuts()
    nmap <unique> <F9>          :call Gdb_togglebreak(bufname("%"), line("."))<CR>
    nmap <unique> <C-F5>        :Gdb run<CR>
    nmap <unique> <F11>          :Gdb step<CR>
    nmap <unique> <F10>          :Gdb next<CR>
    nmap <unique> <F12>          :Gdb finish<CR>
    nmap <unique> <F5>          :Gdb continue<CR>
    nmap <unique> <F8>          :Gdb bt<CR>
    vmap <unique> <C-P>         "gy:Gdb print <C-R>g<CR>
    nmap <unique> <C-P>         :call Gdb_command("print ".expand("<cword>"))<CR>
    call s:InitMenu()
endfunction

" Dump the breakpoints to the file
function s:DumpBreakpoints()
	for val in values(s:BpSet)
		echo val
	endfor
endfunction
