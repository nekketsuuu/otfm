
open Result

let pp = Format.fprintf

type error = [ Otfm.error | `Msg of string ]


let string_of_file inf =
  try
    let ic = if inf = "-" then stdin else open_in_bin inf in
    let close ic = if inf <> "-" then close_in ic else () in
    let buf_size = 65536 in
    let b = Buffer.create buf_size in
    let s = Bytes.create buf_size in
    try
      while true do
        let c = input ic s 0 buf_size in
        if c = 0 then raise Exit else
        Buffer.add_substring b (Bytes.unsafe_to_string s) 0 c
      done;
      assert false
    with
    | Exit -> close ic; Ok (Buffer.contents b)
    | Failure _ -> close ic; Error (`Msg (Printf.sprintf "%s: input file too large" inf))
    | Sys_error e -> close ic; (Error (`Msg e));
  with
  | Sys_error e -> (Error (`Msg e))


let charstring topdict gid =
  match Otfm.charstring_absolute topdict.Otfm.charstring_info gid with
  | Ok(None)      -> Error(`Msg (Printf.sprintf "no CharString for GID %d" gid))
  | Ok(Some(s))   -> Ok(s)
  | Error(e)      -> Error(e :> error)


let main fmt =
  let ( >>= ) x f =
    match x with
    | Ok(v)    -> f v
    | Error(e) -> Error(e :> error)
  in
  let filename = try Sys.argv.(1) with Invalid_argument(_) -> begin print_endline "illegal argument"; exit 1 end in
  let src =
    match string_of_file filename with
    | Ok(src)       -> src
    | Error(`Msg e) -> begin print_endline e; exit 1 end
  in
  Otfm.decoder (`String(src)) >>= function
  | Otfm.SingleDecoder(d) ->
      begin
        print_endline "finish initializing decoder";
        Otfm.cff d >>= fun cffinfo ->
        let (x1, y1, x2, y2) = cffinfo.Otfm.font_bbox in
        pp fmt "FontBBox: (%d, %d, %d, %d)\n" x1 y1 x2 y2;
        pp fmt "IsFixedPitch: %B\n" cffinfo.Otfm.is_fixed_pitch;
        pp fmt "ItalicAngle: %d\n" cffinfo.Otfm.italic_angle;
        pp fmt "UnderlinePosition: %d\n" cffinfo.Otfm.underline_position;
        pp fmt "UnderlineThickness: %d\n" cffinfo.Otfm.underline_thickness;
        pp fmt "PaintType: %d\n" cffinfo.Otfm.paint_type;
        pp fmt "StrokeWidth: %d\n" cffinfo.Otfm.stroke_width;
        charstring cffinfo 32 >>= fun pcs ->
        pp fmt "Raw CharString example:\n";
        pcs |> List.iter (function
        | Otfm.LineTo((x, y)) ->
            Format.fprintf fmt "-- (%d, %d)@ " x y

        | Otfm.BezierTo((xA, yA), (xB, yB), (xC, yC)) ->
            Format.fprintf fmt ".. controls (%d, %d) and (%d, %d) .. (%d, %d)@ " xA yA xB yB xC yC

        | Otfm.CloseAndMoveTo((x, y)) ->
            Format.fprintf fmt "\nstart (%d, %d)@ " x y
        );
        match cffinfo.Otfm.cid_info with
        | None ->
            pp fmt "Not a CIDFont\n";
            Ok()

        | Some(cidinfo) ->
            pp fmt "CIDFont\n";
            pp fmt "Registry: '%s'\n" cidinfo.Otfm.registry;
            pp fmt "Ordering: '%s'\n" cidinfo.Otfm.ordering;
            pp fmt "Supplement: %d\n" cidinfo.Otfm.supplement;
            Ok()
      end

  | Otfm.TrueTypeCollection(_) ->
      begin
        print_endline "TrueType Collection";
        Ok()
      end

let () =
  match main Format.std_formatter with
  | Ok()                    -> ()
  | Error(#Otfm.error as e) -> Format.eprintf "@[%a@]@." Otfm.pp_error e
  | Error(`Msg msg)         -> Format.eprintf "@[%s@]@." msg
