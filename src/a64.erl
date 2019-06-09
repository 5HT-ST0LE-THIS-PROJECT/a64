-module(a64).
-copyright('ARM64 Assembler (c) SYNRC').
-author('Maxim Sokhatsky').
-include("asm.hrl").
-compile(export_all).

main([F])    -> {ok,I} = file:read_file(F), {C,O} = compile(code(I)),
                file:write_file(base(F),O,[raw,write,binary,create]), halt(C);
main(_)      -> io:format("usage: a64 <file>\n"), halt(1).
base(X)      -> filename:basename(X,filename:extension(X)).
atom("#"++X) -> list_to_integer(X);
atom(X)      -> list_to_atom(X).

last(X,Y,A)  ->
  case lists:reverse(X) of
      "]"++Z -> [lists:reverse([atom(lists:reverse(Z))|Y])|A];
           _ -> {[atom(X)|Y],A} end.

code(Bin) ->
  [ lists:reverse(
    lists:foldl(
      fun([$[|X],A) -> last(X,[],A);
         (X,{Y,A}) -> last(X,Y,A);
         (X,A) -> [atom(X)|A] end,[],string:tokens(C," ,")))
   || C <- string:tokens(binary_to_list(Bin),"\n") ].

success(M,F,A) -> try erlang:apply(M,F,A) catch _:_ -> <<>> end.
success_(M,F,A) -> erlang:apply(M,F,A).

compile(Code) ->
   {0,iolist_to_binary([ success(?MODULE,hd(Instr),tl(Instr)) || Instr <- Code])}.

reg(sp)  -> <<31:5>>;
reg(wsp) -> <<31:5>>;
reg(X)   -> <<(list_to_integer(tl(atom_to_list(X)))):5>>.

% C6.2.281 STUR

stur(R1,[R2,Im]) when ?x(R1), ?x(R2), ?imm(Im) ->
   Rt = reg(R1), Rn = reg(R2), I = <<Im:9>>,
   <<3:2,7:3,0:6,I/bitstring,0:2,Rn/bitstring,Rt/bitstring>>;

stur(R1,[R2,Im]) when ?w(R1), ?x(R2), ?imm(Im) ->
   Rt = reg(R1), Rn = reg(R2), I = <<Im:9>>,
   <<2:2,7:3,0:6,I/bitstring,0:2,Rn/bitstring,Rt/bitstring>>.

% C6.2.175 MOV (wide immediate)

mov(R1,Im) when ?x(R1), ?imm(Im) ->
   R = reg(R1), I = <<Im:16>>,
   <<1:1,2:2,37:6,0:2,I/bitstring,R/bitstring>>;

mov(R1,Im) when ?w(R1), ?imm(Im) ->
   R = reg(R1), I = <<Im:16>>,
   <<0:1,2:2,37:6,0:2,I/bitstring,R/bitstring>>.

% C6.2.10 ADRP

adrp(R1,Im) when ?x(R1), ?imm(Im) ->
   Dst = reg(R1), I = <<(Im bsr 2):19>>, J = <<Im:2>>,
   <<1:1,J:2/bitstring,16:5,I:19/bitstring,Dst:5/bitstring>>.

% C6.2.289 SUB (immediate)

sub(R1,R2,Im) when ?x(R1), ?x(R2), ?imm(Im) ->
   Dst = reg(R1), Src = reg(R2), I = <<Im:12>>,
   <<1:1,1:1,0:1,34:6,0:1,I/bitstring,Src/bitstring,Dst/bitstring>>;

sub(R1,R2,Im) when ?w(R1), ?w(R2), ?imm(Im) ->
   Dst = reg(R1), Src = reg(R2), I = <<Im:12>>,
   <<0:1,1:1,0:1,34:6,0:1,I/bitstring,Src/bitstring,Dst/bitstring>>.

% C6.2.4 ADD (immediate)

add(R1,R2,Im) when ?x(R1), ?x(R2), ?imm(Im) ->
   Dst = reg(R1), Src = reg(R2), I = <<Im:12>>,
   <<1:1,0:1,0:1,34:6,0:1,I/bitstring,Src/bitstring,Dst/bitstring>>;

add(R1,R2,Im) when ?w(R1), ?w(R2), ?imm(Im) ->
   Dst = reg(R1), Src = reg(R2), I = <<Im:12>>,
   <<0:1,0:1,0:1,34:6,0:1,I/bitstring,Src/bitstring,Dst/bitstring>>.

% C6.2.256 STP

% Post-index

stp(R1,R2,[R3],Im) when ?w(R1), ?w(R2), ?x(R3), ?imm(Im) ->
   Dst = reg(R1), Src = reg(R2), Rn = reg(R3), I = <<(Im div 4):7>>,
   <<1:2,5:3,0:1,1:3,0:1,I/bitstring,Src/bitstring,Rn/bitstring,Dst/bitstring>>;

stp(R1,R2,[R3],Im) when ?x(R1), ?x(R2), ?x(R3), ?imm(Im) ->
   Dst = reg(R1), Src = reg(R2), Rn = reg(R3), I = <<(Im div 8):7>>,
   <<2:2,5:3,0:1,1:3,0:1,I/bitstring,Src/bitstring,Rn/bitstring,Dst/bitstring>>.

% Signed offset

stp(R1,R2,[R3,Im]) when ?w(R1), ?w(R2), ?x(R3), ?imm(Im) ->
   Dst = reg(R1), Src = reg(R2), Rn = reg(R3), I = <<(Im div 4):7>>,
   <<1:2,5:3,0:1,2:3,0:1,I/bitstring,Src/bitstring,Rn/bitstring,Dst/bitstring>>;

stp(R1,R2,[R3,Im]) when ?x(R1), ?x(R2), ?x(R3), ?imm(Im) ->
   Dst = reg(R1), Src = reg(R2), Rn = reg(R3), I = <<(Im div 8):7>>,
   <<2:2,5:3,0:1,2:3,0:1,I/bitstring,Src/bitstring,Rn/bitstring,Dst/bitstring>>;

% Pre-index

stp(R1,R2,[R3,Im,$!]) when ?w(R1), ?w(R2), ?x(R3), ?imm(Im) ->
   Dst = reg(R1), Src = reg(R2), Rn = reg(R3), I = <<(Im div 4):7>>,
   <<1:2,5:3,0:1,3:3,0:1,I/bitstring,Src/bitstring,Rn/bitstring,Dst/bitstring>>;

stp(R1,R2,[R3,Im,$!]) when ?x(R1), ?x(R2), ?x(R3), ?imm(Im) ->
   Dst = reg(R1), Src = reg(R2), Rn = reg(R3), I = <<(Im div 8):7>>,
   <<2:2,5:3,0:1,3:3,0:1,I/bitstring,Src/bitstring,Rn/bitstring,Dst/bitstring>>.
