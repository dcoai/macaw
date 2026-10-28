# Makes the macaw logo's derived files (#175) from the owner's originals:
#
#     elixir brand/render.exs
#
# - brand/logo/macaw_scarlet.svg, brand/logo/macaw_gold.svg: the originals in
#   brand/originals with their white canvas removed, so the bird sits on
#   whatever is behind it. Exactly one element is removed, the canvas
#   rectangle; anything else differing fails the run.
# - brand/social/<package>.png: a 1280×640 GitHub social preview per
#   package, the scarlet macaw beside the package's name in Space Grotesk
#   600 (SIL OFL 1.1, brand/SpaceGrotesk-OFL.txt), on white.
#
# The tools run in a container built from brand/render.Dockerfile, so the
# host needs only docker. The outputs are committed; run this again only when
# an original changes.

defmodule Brand.Render do
  @moduledoc false

  @root Path.expand("..", __DIR__)
  @image "macaw-brand-render"
  @colors ~w(scarlet gold)
  @packages ~w(macaw macaw_layers macaw_data macaw_component macaw_plug macaw_host macaw_auth macaw_auth_ash)
  @ink "#12385e"

  # The canvas rectangle the drawing tool writes first: white, the whole viewBox.
  @canvas ~r{\n[ \t]*<rect fill="white" x="[\d.]+" y="[\d.]+" width="1449" height="1424"/>}

  def run do
    build_image()
    Enum.each(@colors, &transparent/1)
    Enum.each(@colors, &check_transparent/1)
    Enum.each(@packages, &social/1)
    IO.puts("wrote brand/logo/macaw_{#{Enum.join(@colors, ",")}}.svg and #{length(@packages)} social previews")
  end

  defp transparent(color) do
    original = File.read!(Path.join(@root, "brand/originals/macaw_#{color}.svg"))
    [_one] = Regex.scan(@canvas, original)
    copy = Regex.replace(@canvas, original, "")
    File.write!(Path.join(@root, "brand/logo/macaw_#{color}.svg"), copy)
  end

  # The copy's corners are fully transparent once rendered.
  defp check_transparent(color) do
    png = "/tmp/macaw_#{color}.png"

    alpha =
      container(
        "rsvg-convert -w 200 brand/logo/macaw_#{color}.svg -o #{png} && " <>
          "convert #{png} -format '%[fx:p{0,0}.a] %[fx:p{199,0}.a]' info:"
      )

    "0 0" = String.trim(alpha)
  end

  defp social(package) do
    container(
      Enum.join(
        [
          "rsvg-convert -h 420 brand/logo/macaw_scarlet.svg -o /tmp/logo.png",
          "convert -size 1280x640 xc:white /tmp/logo.png -gravity west -geometry +90+0 -composite " <>
            "-font brand/SpaceGrotesk-600.ttf -fill '#{@ink}' -pointsize #{pointsize(package)} " <>
            "-gravity west -annotate +560+0 '#{package}' -strip brand/social/#{package}.png"
        ],
        " && "
      )
    )

    true = File.stat!(Path.join(@root, "brand/social/#{package}.png")).size < 1_000_000
  end

  # The longest names shrink so each fits beside the bird.
  defp pointsize(package) when byte_size(package) > 12, do: 64
  defp pointsize(_package), do: 96

  defp build_image do
    {_, 0} =
      System.cmd("docker", ["build", "-q", "-t", @image, "-f", "brand/render.Dockerfile", "brand"],
        cd: @root,
        into: IO.stream()
      )
  end

  defp container(script) do
    {out, 0} =
      System.cmd(
        "docker",
        ["run", "--rm", "--user", "#{uid()}:#{gid()}", "-v", "#{@root}:/work", @image, "sh", "-c", script],
        stderr_to_stdout: true
      )

    out
  end

  defp uid, do: String.trim(elem(System.cmd("id", ["-u"]), 0))
  defp gid, do: String.trim(elem(System.cmd("id", ["-g"]), 0))
end

Brand.Render.run()
