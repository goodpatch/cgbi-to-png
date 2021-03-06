defmodule CgbiToPng do

  defstruct length: 0, type: "", data: <<>>, crc: <<>>

  defmodule FileExistError do
    defexception message: "File not exist."
  end

  defmodule FileFormatError do
    defexception message: "This file is not PNG."
  end

  @png_header "iVBORw0KGgo="

  def to_png(file) do
    body = case File.read(file) do
      {:error, _} -> raise FileExistError
      {:ok, body} -> body
    end
    to_png_from_data(body)
  end

  def to_png_from_data(body) do
    << header :: binary-size(8), rest :: binary >> = body
    if to_string(:base64.encode_to_string(header)) != @png_header do
      raise FileFormatError
    end
    << _ :: unsigned-integer-size(32), first_type :: binary-size(4), _ :: binary >> = rest
    case first_type do
      "CgBI" -> convert_png(rest, header, <<>>, 0)
      _ -> body
    end
  end

  defp convert_png(rest, png, all_idats, width) do
    << length :: unsigned-integer-size(32), type :: binary-size(4), rest :: binary >> = rest
    << data :: binary-size(length), crc :: binary-size(4), rest :: binary >> = rest

    chunk = %CgbiToPng{length: length, type: type, data: data, crc: crc}
    case chunk.type do
      "CgBI" ->
        convert_png(rest, png, all_idats, width)
      "IHDR" ->
        << image_width :: unsigned-integer-size(32), image_height :: unsigned-integer-size(32), depth :: size(8), _ :: size(24), filter :: size(8) >> = chunk.data
        width = image_width

        png = png <> <<chunk.length :: unsigned-integer-size(32)>>
        png = png <> chunk.type
        png = png <> chunk.data
        png = png <> chunk.crc
        convert_png(rest, png, all_idats, width)
      "IDAT" ->
        z = :zlib.open()
        :zlib.inflateInit(z, -15)
        decompressed = :zlib.inflate(z, chunk.data)
        :zlib.close(z)

        chunk = %{chunk | data: <<>>}
        decompressed = :erlang.list_to_binary(decompressed)
        all_idats = all_idats <> get_all_idat(decompressed, <<>>, width)
        convert_png(rest, png, all_idats, width)
      "IEND" ->
        bin_list = binary_to_list(all_idats, [])
        z = :zlib.open()
        :zlib.deflateInit(z)
        compressed_idats = :zlib.deflate(z, bin_list, :finish)
        :zlib.close(z)
        compressed_idats = :erlang.list_to_binary(compressed_idats)

        png = png <> <<byte_size(compressed_idats) :: unsigned-integer-size(32)>>
        png = png <> "IDAT"
        png = png <> compressed_idats
        png = png <> <<:erlang.crc32("IDAT" <> compressed_idats) :: unsigned-integer-size(32)>>

        png = png <> <<chunk.length :: unsigned-integer-size(32)>>
        png = png <> chunk.type
        png = png <> chunk.data
        png <> chunk.crc
      _ ->
        png = png <> <<chunk.length :: unsigned-integer-size(32)>>
        png = png <> chunk.type
        png = png <> chunk.data
        png = png <> chunk.crc
        convert_png(rest, png, all_idats, width)
    end
  end

  defp get_all_idat(decompressed, all_idats, width) when decompressed != <<>> do
    << idats :: size(8), rest :: binary >> = decompressed
    all_idats = all_idats <> <<idats>>
    {rest, idats} = convertRGBA(rest, <<>>, 0, width)
    all_idats = all_idats <> idats
    get_all_idat(rest, all_idats, width)
  end

  defp get_all_idat(decompressed, all_idats, width) when decompressed == <<>> do
    all_idats
  end

  defp convertRGBA(rest, rgba_data, i, width) when i != width do
    i = i + 1
    << b :: size(8), g :: size(8), r :: size(8), a :: size(8), rest :: binary >> = rest
    rgba_data = rgba_data <> <<r :: size(8), g :: size(8), b :: size(8), a :: size(8)>>
    convertRGBA(rest, rgba_data, i, width)
  end

  defp convertRGBA(rest, rgba_data, i, width) when i == width do
    {rest, rgba_data}
  end

  defp binary_to_list(bin, res) do
    size = byte_size(bin)
    if size > 4000 do
      << part :: binary-size(4000), rest :: binary >> = bin
      res = res ++ [part]
      binary_to_list(rest, res)
    else
      res ++ [bin]
    end
  end
end
