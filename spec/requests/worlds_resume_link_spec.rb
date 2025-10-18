# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Worlds /resume/:code", type: :request do
  def json; JSON.parse(response.body); end

  it "returns the world for a valid save_code" do
    post "/worlds", params: { seed: "banana" }
    code = World.last.save_code

    get "/resume/#{code}"
    expect(response).to have_http_status(:ok)
    expect(json).to include("world_id", "state", "messages")
  end

  it "returns 404 for an invalid code" do
    get "/resume/NOTREAL"
    expect(response).to have_http_status(:not_found)
    expect(json).to include("error")
  end
end
