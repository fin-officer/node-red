// Funkcje pomocnicze dla obsługi emaili
module.exports = {
    // Prosta funkcja do konwersji HTML do tekstu
    htmlToText: function(html) {
        if (!html) return "";

        // Usuń tagi HTML
        let text = html.replace(/<[^>]*>/g, " ");

        // Normalizuj białe znaki
        text = text.replace(/\s+/g, " ").trim();

        // Zastąp encje HTML
        text = text.replace(/&nbsp;/g, " ")
                   .replace(/&amp;/g, "&")
                   .replace(/&lt;/g, "<")
                   .replace(/&gt;/g, ">")
                   .replace(/&quot;/g, "\"")
                   .replace(/&#39;/g, "'");

        return text;
    }
};
