let u16_of_bytes high low =
  (high lsl 8) lor low

let read_file_bytes filename =
  let ic = open_in_bin filename in
  let len = in_channel_length ic in
  let s = really_input_string ic len in
  close_in ic;
  List.init (String.length s) (fun i -> Char.code s.[i])

let write_string_to_file filename text =
  let outc = Out_channel.open_text filename in
  Out_channel.output_string outc text;
  Out_channel.close outc

let string_of_bytestream bs =
  match bs with
  | _ :: _ :: code -> (
    let rec aux acc left =
      match left with
      | [] -> acc
      | 0x00 :: rest -> aux (Printf.sprintf "%s\n%s" acc "halt") rest
      | 0x01 :: immediate :: rest -> aux (Printf.sprintf "%s\n%s 0x%x" acc "push" immediate) rest

      (* Simple Arithmetics *)
      | 0x02 :: rest -> aux (Printf.sprintf "%s\n%s" acc "pop") rest
      | 0x03 :: rest -> aux (Printf.sprintf "%s\n%s" acc "add") rest
      | 0x04 :: rest -> aux (Printf.sprintf "%s\n%s" acc "sub") rest
      | 0x05 :: rest -> aux (Printf.sprintf "%s\n%s" acc "mul") rest
      | 0x06 :: rest -> aux (Printf.sprintf "%s\n%s" acc "div") rest

      (* Jump Opcodes *)
      | 0x07 :: target :: rest -> aux (Printf.sprintf "%s\n%s 0x%x" acc "jmp" target) rest
      | 0x08 :: target :: rest -> aux (Printf.sprintf "%s\n%s 0x%x" acc "jig" target) rest
      | 0x09 :: target :: rest -> aux (Printf.sprintf "%s\n%s 0x%x" acc "jie" target) rest
      | 0x0a :: target :: rest -> aux (Printf.sprintf "%s\n%s 0x%x" acc "jis" target) rest
      | 0x0b :: target :: rest -> aux (Printf.sprintf "%s\n%s 0x%x" acc "jiz" target) rest
      | 0x0f :: target :: rest -> aux (Printf.sprintf "%s\n%s 0x%x" acc "jnz" target) rest

      (* Basic I/O *)
      | 0x0d :: rest -> aux (Printf.sprintf "%s\n%s" acc "putn") rest
      | 0x0e :: rest -> aux (Printf.sprintf "%s\n%s" acc "putc") rest

      (* Memory *)
      | 0x10 :: rest -> aux (Printf.sprintf "%s\n%s" acc "dup") rest
      | 0x11 :: address :: rest -> aux (Printf.sprintf "%s\n%s 0x%x" acc "store" address) rest
      | 0x12 :: address :: rest -> aux (Printf.sprintf "%s\n%s 0x%x" acc "load" address) rest

      (* Extended Arithmetics *)
      | 0x13 :: rest -> aux (Printf.sprintf "%s\n%s" acc "mod") rest
      | 0x14 :: rest -> aux (Printf.sprintf "%s\n%s" acc "inc") rest
      | 0x15 :: rest -> aux (Printf.sprintf "%s\n%s" acc "dec") rest
      | 0x16 :: rest -> aux (Printf.sprintf "%s\n%s" acc "neg") rest
      | 0x17 :: rest -> aux (Printf.sprintf "%s\n%s" acc "and") rest
      | 0x18 :: rest -> aux (Printf.sprintf "%s\n%s" acc "or") rest
      | 0x19 :: rest -> aux (Printf.sprintf "%s\n%s" acc "xor") rest
      | 0x1a :: rest -> aux (Printf.sprintf "%s\n%s" acc "not") rest
      | 0x1b :: rest -> aux (Printf.sprintf "%s\n%s" acc "shl") rest
      | 0x1c :: rest -> aux (Printf.sprintf "%s\n%s" acc "shr") rest
      | 0x1d :: rest -> aux (Printf.sprintf "%s\n%s" acc "min") rest
      | 0x1e :: rest -> aux (Printf.sprintf "%s\n%s" acc "max") rest
      | 0x1f :: rest -> aux (Printf.sprintf "%s\n%s" acc "cmp") rest

      (* Stack Manipulation *)
      | 0x20 :: rest -> aux (Printf.sprintf "%s\n%s" acc "swap") rest
      | 0x21 :: rest -> aux (Printf.sprintf "%s\n%s" acc "over") rest
      | 0x22 :: rest -> aux (Printf.sprintf "%s\n%s" acc "rot") rest
      | 0x23 :: rest -> aux (Printf.sprintf "%s\n%s" acc "nip") rest
      | 0x24 :: rest -> aux (Printf.sprintf "%s\n%s" acc "tuck") rest
      | 0x25 :: rest -> aux (Printf.sprintf "%s\n%s" acc "dup2") rest
      | 0x26 :: rest -> aux (Printf.sprintf "%s\n%s" acc "drop2") rest
      | 0x27 :: rest -> aux (Printf.sprintf "%s\n%s" acc "swap2") rest
      | 0x28 :: rest -> aux (Printf.sprintf "%s\n%s" acc "depth") rest

      (* Memory Operations *)
      | 0x30 :: rest -> aux (Printf.sprintf "%s\n%s" acc "fetch") rest
      | 0x31 :: rest -> aux (Printf.sprintf "%s\n%s" acc "storei") rest
      | 0x32 :: high :: low :: rest -> aux (Printf.sprintf "%s\n%s %x" acc "fill" (u16_of_bytes high low)) rest
      | 0x33 :: rest -> aux (Printf.sprintf "%s\n%s" acc "fetch16") rest
      | 0x34 :: rest -> aux (Printf.sprintf "%s\n%s" acc "storei16") rest
      | 0x35 :: rest -> aux (Printf.sprintf "%s\n%s" acc "putsn") rest
      | 0x36 :: rest -> aux (Printf.sprintf "%s\n%s" acc "strcmp") rest
      | 0x37 :: rest -> aux (Printf.sprintf "%s\n%s" acc "alloc") rest
      | 0x38 :: rest -> aux (Printf.sprintf "%s\n%s" acc "aget") rest
      | 0x39 :: rest -> aux (Printf.sprintf "%s\n%s" acc "alen") rest
      | 0x3a :: rest -> aux (Printf.sprintf "%s\n%s" acc "loadrel") rest
      | 0x3b :: rest -> aux (Printf.sprintf "%s\n%s" acc "aset") rest

      (* Control Flow *)
      | 0x40 :: addr :: rest -> aux (Printf.sprintf "%s\n%s 0x%x" acc "call" addr) rest
      | 0x41 :: rest -> aux (Printf.sprintf "%s\n%s" acc "ret") rest
      | 0x42 :: rest -> aux (Printf.sprintf "%s\n%s" acc "execute") rest
      | 0x43 :: target :: rest -> aux (Printf.sprintf "%s\n%s 0x%x" acc "jgt" target) rest
      | 0x44 :: target :: rest -> aux (Printf.sprintf "%s\n%s 0x%x" acc "jlt" target) rest
      | 0x45 :: target :: rest -> aux (Printf.sprintf "%s\n%s 0x%x" acc "jeq" target) rest
      | 0x46 :: target :: rest -> aux (Printf.sprintf "%s\n%s 0x%x" acc "loop" target) rest

      (* Advanced I/O *)
      | 0x50 :: rest -> aux (Printf.sprintf "%s\n%s" acc "emit") rest
      | 0x51 :: rest -> aux (Printf.sprintf "%s\n%s" acc "cr") rest
      | 0x52 :: rest -> aux (Printf.sprintf "%s\n%s" acc "space") rest
      | 0x53 :: rest -> aux (Printf.sprintf "%s\n%s" acc "key") rest
      | 0x54 :: rest -> aux (Printf.sprintf "%s\n%s" acc "puts") rest
      | 0x55 :: rest -> aux (Printf.sprintf "%s\n%s" acc "strlen") rest
      | 0x56 :: rest -> aux (Printf.sprintf "%s\n%s" acc "putc_pop") rest
      | 0x57 :: rest -> aux (Printf.sprintf "%s\n%s" acc "putn_pop") rest

      (* System *)
      | 0x60 :: rest -> aux (Printf.sprintf "%s\n%s" acc "ddepth") rest
      | 0x61 :: rest -> aux (Printf.sprintf "%s\n%s" acc "rdepth") rest
      | 0x62 :: rest -> aux (Printf.sprintf "%s\n%s" acc "msize") rest
      | 0x63 :: rest -> aux (Printf.sprintf "%s\n%s" acc "state") rest
      | 0x64 :: rest -> aux (Printf.sprintf "%s\n%s" acc "bye") rest

      (* 16-bit extensions *)
      | 0x70 :: high :: low :: rest -> aux (Printf.sprintf "%s\n%s 0x%x" acc "push16" (u16_of_bytes high low)) rest
      | 0x71 :: high :: low :: rest -> aux (Printf.sprintf "%s\n%s 0x%x" acc "jmp16" (u16_of_bytes high low)) rest
      | 0x72 :: high :: low :: rest -> aux (Printf.sprintf "%s\n%s 0x%x" acc "call16" (u16_of_bytes high low)) rest
  
      | x :: rest -> aux acc rest
    in (aux "" code) ^ "\n"
  )
  | _ -> ""

let () =
  match Sys.argv with
  | [|_; input_file|] -> (
    try
      let byte_stream = read_file_bytes input_file in
      print_endline (string_of_bytestream byte_stream)
    with Sys_error e -> (
      Printf.printf "Error while writing to file: %s\n" e;
      exit 1
    )
  )

  | [|_; input_file; output_file|] -> (
    try
      let byte_stream = read_file_bytes input_file in
      write_string_to_file output_file (string_of_bytestream byte_stream)
    with Sys_error e -> (
      Printf.printf "Error while writing to file: %s\n" e;
      exit 1
    )
  )

  | _ -> (
    print_endline "Usage: atomdisasm <input file> <?output file?>";
    exit 1
  )
