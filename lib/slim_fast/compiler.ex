defmodule SlimFast.Compiler do
  @void_elements ~w(
    area br col doctype embed hr img input link meta base param keygen source menuitem track wbr
  )a

  def compile(tree) do
    tree
    |> Enum.map(fn branch -> render_branch(branch) end)
    |> Enum.join
    |> String.replace("\r", "")
  end

  defp render_attribute(_, []), do: ""
  defp render_attribute(_, ""), do: ""
  defp render_attribute(name, {:eex, opts}) do
    value = opts[:content]
    case value do
      "true" -> " #{to_string(name)}"
      "false" -> ""
      "nil" -> ""
      _ ->  ~s[<% slim__k = "#{to_string(name)}"; slim__v = #{value} %><%= if slim__v do %> <%= slim__k %><%= unless slim__v == true do %>="<%= slim__v %>"<% end %><% end %>]
    end
  end

  defp render_attribute(name, value) do
    value = cond do
              is_binary(value) -> value
              is_list(value) -> Enum.join(value, " ")
              true -> to_string(value)
            end

    ~s( #{to_string(name)}="#{value}")
  end

  defp render_branch(%{type: :doctype, content: text}), do: text
  defp render_branch(%{type: :text, content: text}), do: text
  defp render_branch(%{} = branch) do
    opening = branch.attributes
              |> Enum.map(fn {k, v} -> render_attribute(k, v) end)
              |> Enum.join
              |> open(branch)

    closing = close(branch)
    opening <> compile(branch.children) <> closing
  end

  defp open(_, %{type: :eex, content: code, attributes: attrs}) do
    inline = if attrs[:inline], do: "=", else: ""
    "<%#{inline} #{code} %>\r"
  end

  defp open(_, %{type: :html_comment}), do: "<!--"
  defp open(_, %{type: :ie_comment, content: conditions}), do: "<!--[#{conditions}]>"
  defp open(attrs, %{type: type, spaces: spaces, close: close}) do
    "#{if spaces[:leading], do: " "}<#{String.rstrip("#{type}#{attrs}")}#{if close, do: "/"}>"
  end

  defp close(%{type: type, spaces: spaces}) when type in @void_elements do
    if spaces[:trailing], do: " ", else: ""
  end

  defp close(%{type: :html_comment}), do: "-->"
  defp close(%{type: :ie_comment}), do: "<![endif]-->"
  defp close(%{type: :eex, content: code}) do
    cond do
      Regex.match? ~r/(fn.*->| do)\s*$/, code -> "<% end %>"
      true -> ""
    end
  end

  defp close(%{type: type, spaces: spaces}) do
    "</#{type}>#{if spaces[:trailing], do: " "}"
  end
end
