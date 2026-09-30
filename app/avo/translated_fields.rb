# One tab per supported language, with the resource's translated attributes,
# each read and written exactly in that language (Translatable accessors).
module Avo::TranslatedFields
  def translation_tabs(*attributes, long: [])
    tabs do
      Translation::SUPPORTED_LOCALES.each do |locale|
        tab title: locale.upcase do
          attributes.each do |attribute|
            field :"#{attribute}_#{locale}", as: (long.include?(attribute) ? :textarea : :text),
              name: "#{I18n.t("admin.fields.#{attribute}")} (#{locale})", hide_on: :index
          end
        end
      end
    end
  end
end
