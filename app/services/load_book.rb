require 'pdf-reader'
require 'openai'
require 'csv'
require 'daru'
require 'tokenizers'

class LoadBook < ApplicationService
  def call
    load_book
  end

  private

  def load_book
    client = OpenAI::Client.new
    reader = PDF::Reader.new(Constants::FILE_NAME)
    response = []
    i = 1

    reader.pages.each_with_index do |page, index|
      page_text = page.text
      content = page_text.gsub(/\s+/, ' ')
      response << ["Page #{index + 1}", content, count_tokens(content) + 4]
    end

    keys = %w(title content tokens)
    response = response.map { |values| Hash[keys.zip(values)] }

    df = Daru::DataFrame.new(response)
    df = df.where(df['tokens'].lt(2046))
    df.head

    result = dataframe_write_csv(df, Constants::FILE_NAME_CSV, { headers: false })

    doc_embeddings = compute_doc_embeddings(df, client)

    CSV.open(Constants::CSV_FILE_PATH, 'wb') do |csv|
      csv << ["title"] + (0...4096).to_a

      doc_embeddings.each_with_index do |embedding, index|
        csv << ["Page #{index + 1}"] + embedding[1]
      end
    end
  end


    def dataframe_write_csv(dataframe, path, opts={})
      options = {
        converters: :numeric
      }.merge(opts)

      writer = CSV.open(path, 'w')
      writer << dataframe.vectors.to_a

      dataframe.each_row do |row|
        writer << if options[:convert_comma]
                    row.map { |v| v.to_s.tr('.', ',') }
                  else
                    row.to_a
                  end
      end

      writer.close

    end

    def count_tokens(text)
      Tokenizers.from_pretrained('gpt2').encode(text).ids.length
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


    def compute_doc_embeddings(df, client)
      embeddings = {}

      df.each_row_with_index do |row, index|
        embeddings[index] = get_doc_embedding(row['content'], client)
      end

      embeddings
    end
end