class Api::V1::QuestionsController < ApplicationController

  def handle_question
    result = HandleQuestions.new(params).call

    render json: result , status: :ok
  end

private

  def question_params
    params.require(:question).permit(:title)
  end
end
