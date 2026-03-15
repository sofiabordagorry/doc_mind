defmodule DocMindWeb.AskAnswerTest do
  use DocMindWeb.ConnCase, async: true

  test "renders nothing when answer is nil" do
    html = render_component(&DocMindWeb.AskAnswer.ask_answer/1, answer: nil)

    refute html =~ "Answer"
  end

  test "renders the answer text" do
    answer = %DocMind.Answer{
      answer: "A GenServer is an abstraction over a process that manages state.",
      sources: []
    }

    html = render_component(&DocMindWeb.AskAnswer.ask_answer/1, answer: answer)

    assert html =~ "Answer"
    assert html =~ "A GenServer is an abstraction"
  end

  test "renders the sources list" do
    answer = %DocMind.Answer{
      answer: "Some answer. [1]",
      sources: [
        %{source: "README.md", heading: "Overview"},
        %{source: "https://hexdocs.pm/elixir/GenServer.html", heading: nil}
      ]
    }

    html = render_component(&DocMindWeb.AskAnswer.ask_answer/1, answer: answer)

    assert html =~ "Sources"
    assert html =~ "README.md"
    assert html =~ "Overview"
    assert html =~ "https://hexdocs.pm/elixir/GenServer.html"
  end

  test "does not render sources section when sources list is empty" do
    answer = %DocMind.Answer{answer: "Some answer.", sources: []}

    html = render_component(&DocMindWeb.AskAnswer.ask_answer/1, answer: answer)

    assert html =~ "Answer"
    refute html =~ "Sources"
  end
end
