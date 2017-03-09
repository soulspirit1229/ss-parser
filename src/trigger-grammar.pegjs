{
  const makeInteger = (int) => parseInt(int.join(""), 10);

  const starminmax = (min, max) => {
    min = parseInt(min, 10);
    max = parseInt(max, 10);
    if (min === 0) {
      return `\\s*((?:[^\\s]+\\s+){${min},${max - 1}}(?:[^\\s]+)?)\\s*`;
    } else {
      return `\\s*((?:[^\\s]+\\s+){${min - 1},${max - 1}}(?:[^\\s]+))\\s*`;
    }
  }
}

start
  = trigger

star
  = "*" { return { raw: "*", clean: "(?:\\s*(?:.*)\\s*)?" }; }
  / "(" ws* "*" ws* ")" { return { raw: "(*)", clean: "\\s*(.*)\\s*" }; }

// As far as I can tell: * and [*] are equivalent and can be empty, while (*) cannot
// match to an empty string.

starn
  = "*" val:integer { return { raw: `*${val}`, clean: `\\s*((?:[^\\s]){${val}})` }; }
  / "*(" val:integer ")" { return { raw: `*(${val})`, clean: `\\s*((?:[^\\s]){${val}})` }; }

starupton
  = "*~" val:integer { return { raw: `*~${val}`, clean: `\\s*((?:[^\\s]){0,${val}})` }; }

starminmax
  = "*(" ws* min:integer ws* "," ws* max:integer ws* ")"
    { return { raw: `*(${min},${max})`, clean: `\\s*((?:[^\\s]){${min},${max}})` }; }
  / "*(" ws* min:integer ws* "-" ws* max:integer ws* ")"
    { return { raw: `*(${min},${max})`, clean: `\\s*((?:[^\\s]){${min},${max}})` }; }

string
  = str:[a-zA-Z\u4e00-\u9fa5]+ { return { type: "string", val: str.join("")}; }

cleanedString
  = wsl:ws* string:[^|()\[\]\n\r*]+ wsr:ws* { return string.join(""); }

alternates
  = "(" alternate:cleanedString alternates:("|" cleanedString:cleanedString { return cleanedString; } )+ ")"
    {
      const cleaned = [alternate].concat(alternates).join("|");
      return {
        raw: `(${cleaned})`,
        clean: `\\s*(${cleaned})\\s*`
      };
    }

optionals
  = "[" optional:cleanedString optionals:("|" cleanedString:cleanedString { return cleanedString; } )* "]"
    {
      const cleaned = [optional].concat(optionals).join("|");
      return {
        raw: `[${cleaned}]`,
        clean: `(?:(?:)+(?:${cleaned})(?:)+|(?:)+)`
      };
    }
  / "[" ws* "*" ws* "]"
    {
      return {
        raw: "[*]",
        clean: "(?:(?:(?:)+(?:.*)(?:)+|(?:)+)|)"
      };
    }

EOF
  = !.

triggerTokens
  = wsl:ws* alternates:alternates wsr:ws*
    { return { raw: `${alternates.raw}`, clean: alternates.clean } }
  / wsl:ws* optionals:optionals wsr:ws*
    { return { raw: `${optionals.raw}`, clean: optionals.clean } }
  / wsl:ws* starn:starn wsr:ws*
    { return { raw: `${starn.raw}`, clean: starn.clean }; }
  / wsl:ws* starupton:starupton wsr:ws*
    { return { raw: `${starupton.raw}`, clean: starupton.clean }; }
  / wsl:ws* starminmax:starminmax wsr:ws*
    { return { raw: `${starminmax.raw}`, clean: starminmax.clean }; }
  / wsl:ws* star:star wsr:ws*
    { return { raw: `${star.raw}`, clean: star.clean }; }
  / string:escapedCharacter+
    { return { raw: string.join(""), clean: `${string.join("")}` };}
  / ws:ws
    { return { raw: ws, clean: ws }; }

trigger
  = tokens:triggerTokens*
    {
      return {
        raw: tokens.map((token) => token.raw).join(""),
        clean: tokens.map((token) => token.clean).join("")
      };
    }

escapedCharacter
  = "\\" character:[*~?\[\]\(\)]
    { return `\\${character}`; }
  / character:[+?*]
    { return `\\${character}`; }
  / character:[^*\n\r \t]
    { return character; }

integer "integer"
  = digits:[0-9]+ { return makeInteger(digits); }

ws "whitespace" = [ \t]

nl "newline" = [\n\r]
