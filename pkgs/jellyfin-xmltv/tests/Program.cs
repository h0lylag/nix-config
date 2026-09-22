using Jellyfin.XmlTv;

const string artwork = "http://example.invalid/poster.jpg";
const string image = $"<image size=\"3\">{artwork}</image>";
const string icon = $"<icon src=\"{artwork}\"/>";

var cases = new (string Name, string Elements, int Images)[]
{
    ("compact image followed by icon", image + icon, 1),
    ("icon followed by image", icon + image, 1),
    ("image followed by newline and icon", image + "\n" + icon, 1),
    ("icon without image", icon, 0),
    ("adjacent images followed by icon", image + image + icon, 2),
};

foreach (var test in cases)
{
    var path = Path.GetTempFileName();
    try
    {
        var xml = "<tv><channel id=\"test\"><display-name>Test</display-name></channel>";
        // Use two programmes to check that parsing stays aligned after artwork.
        for (var number = 1; number <= 2; number++)
        {
            xml += $"<programme channel=\"test\" start=\"202609220{number}0000 +0000\" stop=\"202609220{number}3000 +0000\">"
                + $"<title>Programme {number}</title>{test.Elements}</programme>";
        }
        File.WriteAllText(path, xml + "</tv>");

        var reader = new XmlTvReader(path);
        var programmes = reader.GetProgrammes("test", DateTimeOffset.MinValue, DateTimeOffset.MaxValue).ToList();
        if (reader.GetChannels().Count() != 1 || programmes.Count != 2)
            throw new InvalidOperationException($"{test.Name}: channel or programme lost");

        for (var index = 0; index < programmes.Count; index++)
        {
            var programme = programmes[index];
            var icons = programme.Icons;
            if (programme.Title != $"Programme {index + 1}" || icons is null || icons.Count != 1 || icons[0].Source != artwork)
                throw new InvalidOperationException($"{test.Name}: programme title or icon lost");
            if ((programme.Images?.Count ?? 0) != test.Images || programme.Images?.Any(i => i.Path != artwork) == true)
                throw new InvalidOperationException($"{test.Name}: programme image lost or changed");
        }

        Console.WriteLine($"PASS: {test.Name}");
    }
    finally
    {
        File.Delete(path);
    }
}

if (typeof(XmlTvReader).Assembly.GetName().Version != new Version(1, 0, 0, 0))
    throw new InvalidOperationException("The replacement parser must retain Jellyfin's assembly identity");
