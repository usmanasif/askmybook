require 'pdf-reader'
require 'openai'
require 'csv'
require 'daru'
require 'tokenizers'

class HandleQuestions < ApplicationService
  attr_accessor :params

  def initialize(params)
    @params = params
  end
  
  def call
    handle_question
  end

  private

    def handle_question
      
      LoadBook.call if !File.exist?(Constants::FILE_NAME_EMBEDDED)

      prev_question = params[:title].present? ? Question.find_by(question: params[:title]) : Question.find_by(id: params[:id]) 

      if prev_question
        prev_question['ask_count'] += 1
        
        return { error: 'Couldn\'t save record' } unless prev_question.save

        cache_response = Rails.cache.read(prev_question.question)

        { question: prev_question.question, answer: cache_response, id: prev_question.id }
      else
        df = Daru::DataFrame.from_csv(Constants::FILE_NAME_CSV, {})
        document_embeddings = load_embeddings
        answer, context = answer_query_with_context(params[:title], df, document_embeddings)
        new_question = Question.new(question: params[:title], answer: answer, context: context)

        return { error: 'Couldn\'t create question' } unless new_question.save

        cache_response = Rails.cache.write(new_question.question, new_question.answer)
        
        { question: new_question.question, answer: answer, id: new_question.id }
      end
    end

    def vector_similarity(x, y)
      x_array = x.to_a
      y_array = y.to_a
      dot_product = 0

      x_array.each_with_index do |x_value, index|
        dot_product += x_value * y_array[index]
      end

      dot_product
    end

    def order_document_sections_by_query_similarity(query, contexts)
      client = OpenAI::Client.new
      query_embeddings = get_doc_embedding(query, client)

      document_similarities = contexts.map do |doc_index, doc_embedding| 
        [vector_similarity(query_embeddings, doc_embedding), doc_index]
      end
      
      document_similarities.sort.reverse
    end

    def construct_prompt(question, context_embeddings, df)
      most_relevant_document_sections = order_document_sections_by_query_similarity(question, context_embeddings)

      chosen_sections = []
      chosen_sections_len = 0
      chosen_sections_indexes = []

      most_relevant_document_sections.each do |_, section_index|
        document_section = df.where(title: section_index).row[0]

        chosen_sections_len += document_section['tokens'] + 3
        
        if chosen_sections_len > 500
          space_left = 500 - chosen_sections_len - '\n* '.length
          chosen_sections.push("\n* #{document_section['content'][0...space_left]}")
          chosen_sections_indexes.push(section_index.to_s)
          break
        end

        chosen_sections.push("\n* #{document_section[:content]}")
        chosen_sections_indexes.push(section_index.to_s)
      end

      [header + chosen_sections.join + sample_questions.join + "\n\n\nQ: " + question + "\n\nA: ", [chosen_sections.join]]
    end

    def header
      "Sahil Lavingia is the founder and CEO of Gumroad, and the author of the book The Minimalist Entrepreneur (also known as TME). These are questions and answers by him. Please keep your answers to three sentences maximum, and speak in complete sentences. Stop speaking once your point is made.\n\nContext that may be useful, pulled from The Minimalist Entrepreneur:\n"
    end

    def sample_questions
      [
        "\n\n\nQ: How to choose what business to start?\n\nA: First off don't be in a rush. Look around you, see what problems you or other people are facing, and solve one of these problems if you see some overlap with your passions or skills. Or, even if you don't see an overlap, imagine how you would solve that problem anyway. Start super, super small.",
        "\n\n\nQ: Q: Should we start the business on the side first or should we put full effort right from the start?\n\nA:   Always on the side. Things start small and get bigger from there, and I don't know if I would ever 'fully' commit to something unless I had some semblance of customer traction. Like with this product I'm working on now!",
        "\n\n\nQ: Should we sell first than build or the other way around?\n\nA: I would recommend building first. Building will teach you a lot, and too many people use 'sales' as an excuse to never learn essential skills like building. You can't sell a house you can't build!",
        "\n\n\nQ: Andrew Chen has a book on this so maybe touché, but how should founders think about the cold start problem? Businesses are hard to start, and even harder to sustain but the latter is somewhat defined and structured, whereas the former is the vast unknown. Not sure if it's worthy, but this is something I have personally struggled with\n\nA: Hey, this is about my book, not his! I would solve the problem from a single player perspective first. For example, Gumroad is useful to a creator looking to sell something even if no one is currently using the platform. Usage helps, but it's not necessary.",
        "\n\n\nQ: What is one business that you think is ripe for a minimalist Entrepreneur innovation that isn't currently being pursued by your community?\n\nA: I would move to a place outside of a big city and watch how broken, slow, and non-automated most things are. And of course the big categories like housing, transportation, toys, healthcare, supply chain, food, and more, are constantly being upturned. Go to an industry conference and it's all they talk about! Any industry…",
        "\n\n\nQ: How can you tell if your pricing is right? If you are leaving money on the table\n\nA: I would work backwards from the kind of success you want, how many customers you think you can reasonably get to within a few years, and then reverse engineer how much it should be priced to make that work.",
        "\n\n\nQ: Why is the name of your book 'the minimalist entrepreneur' \n\nA: I think more people should start businesses, and was hoping that making it feel more 'minimal' would make it feel more achievable and lead more people to starting-the hardest step.",
        "\n\n\nQ: How long it takes to write TME\n\nA: About 500 hours over the course of a year or two, including book proposal and outline.",
        "\n\n\nQ: What is the best way to distribute surveys to test my product idea\n\nA: I use Google Forms and my email list / Twitter account. Works great and is 100% free.",
        "\n\n\nQ: How do you know, when to quit\n\nA: When I'm bored, no longer learning, not earning enough, getting physically unhealthy, etc… loads of reasons. I think the default should be to 'quit' and work on something new. Few things are worth holding your attention for a long period of time."
      ]
    end


    def answer_query_with_context(query, df, document_embeddings)
      prompt, context = construct_prompt(query, document_embeddings, df)

      client = OpenAI::Client.new
      response = client.completions(
        parameters: {
            model: Constants::DOC_COMPLETION_MODEL,
            temperature: 0.0,
            max_tokens: 150, 
            prompt: prompt
        }
      )

      [response['choices'][0]['text'].strip, context]
    end

    def load_embeddings
      df = Daru::DataFrame.from_csv(Constants::FILE_NAME_EMBEDDED, {})
      max_dim = df.vectors.to_a[1..].max
      document_embeddings = {}

      df.each_row_with_index do |row, index|
        list = []

        (0..max_dim + 1).map do |idx|
          list.append(row[idx])
          document_embeddings[row['title']] = list
        end
      end

      document_embeddings
    end


    def get_doc_embedding(text, client)
      result = client.embeddings(
        parameters: {
          model: Constants::DOC_EMBEDDINGS_MODEL,
          input: text
        }
      )

      result['data'][0]['embedding']
    end
end