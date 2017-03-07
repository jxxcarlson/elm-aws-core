module AWS.Encode exposing (..)

import Char
import Hex
import Http
import Json.Encode as JE
import Regex exposing (regex, HowMany(All))


{-| We don't use Http.encodeUri because it misses some characters. It uses the
native `encodeURIComponent` under the hood:

    encodeURIComponent escapes all characters except the following:
    alphabetic, decimal digits, - _ . ! ~ * ' ( )

    - from https://developer.mozilla.org/en/docs/Web/JavaScript/Reference/Global_Objects/encodeURIComponent

For AWS only "Unreserved Characters" are allowed.
See http://tools.ietf.org/html/rfc3986
Section 2.3

So basically we need to also cover: ! * ' ( )
-}
uri : String -> String
uri x =
    x
        |> Http.encodeUri
        |> Regex.replace All
            (regex "[!*'()]")
            (\match ->
                match.match
                    |> String.toList
                    |> List.head
                    |> Maybe.map
                        (\char ->
                            char
                                |> Char.toCode
                                |> Hex.toString
                                |> String.toUpper
                                |> (++) "%"
                        )
                    |> Maybe.withDefault ""
            )


optionalMember :
    (a -> JE.Value)
    -> ( String, Maybe a )
    -> List ( String, JE.Value )
    -> List ( String, JE.Value )
optionalMember encode ( key, maybeValue ) members =
    case maybeValue of
        Nothing ->
            members

        Just value ->
            ( key, encode value ) :: members