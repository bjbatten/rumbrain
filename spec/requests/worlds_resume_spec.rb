# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Worlds /resume", type: :request do
  def json; JSON.parse(response.body); end

  it "resumes an existing world by save_code" do
    post "/worlds", params: { seed: "banana" }
    expect(response).to have_http_status(:created)
    code = JSON.parse(response.body)["state"].present? &&
           World.last.save_code

    get "/worlds/resume", params: { code: code }
    expect(response).to have_http_status(:ok)
    expect(json).to include("world_id", "state", "messages")
  end

  it "404s for unknown save_code" do
    get "/worlds/resume", params: { code: "doesnotexist" }
    expect(response).to have_http_status(:not_found)
    expect(json).to include("error")
  end
end
