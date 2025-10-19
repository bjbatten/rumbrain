class AssetsController < ApplicationController
  # Serve static game assets from public/assets
  # GET /assets/:name
  def show
    # Rails may strip the extension into request.format, so reconstruct filename
    base = params[:name].to_s
    ext = request.format.try(:ref) || File.extname(base)
    # If request.format is like :png, build ".png"
    ext = ".#{ext}" unless ext.to_s.start_with?(".")

    filename = base.end_with?(ext) ? base : "#{base}#{ext}"

    # reject any directory traversal attempts
    if filename.include?("..") || filename.start_with?("/") || filename.match?(/[\0\n\r\t]/)
      render plain: "Invalid asset name", status: :bad_request and return
    end

    asset_path = Rails.root.join("public", "assets", filename)

    unless File.exist?(asset_path) && File.file?(asset_path)
      # Try serving a local fallback image if present
      fallback = Rails.root.join("public", "adventure-game-room.jpg")
      if File.exist?(fallback)
        send_file fallback, type: "image/jpeg", disposition: "inline", cache_control: "public, max-age=31536000, immutable" and return
      end

      # As a last resort redirect to the frontend's public image (development convenience)
      # Adjust this URL if your frontend runs on a different host/port in dev.
      redirect_to "http://localhost:3000/adventure-game-room.jpg" and return
    end

    send_file asset_path, type: mime_type_for(filename), disposition: "inline", cache_control: "public, max-age=31536000, immutable"
  end

  private

  def mime_type_for(name)
    case File.extname(name).downcase
    when ".png" then "image/png"
    when ".jpg", ".jpeg" then "image/jpeg"
    when ".webp" then "image/webp"
    when ".svg" then "image/svg+xml"
    else
      "application/octet-stream"
    end
  end
end
