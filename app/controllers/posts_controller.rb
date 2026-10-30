class PostsController < ApplicationController
  def timeline
    TimelinePagePresenter.new(repository: content_repository, order: params[:order], query: params[:q], view: params[:view]).assigns.each do |key, value|
      instance_variable_set("@#{key}", value)
    end
  end
end
