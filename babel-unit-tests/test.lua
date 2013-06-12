
describe( "Babel Unit Tests", function()

    local babel
    local test_date

    --- Initialize babel and load test translations from the
    -- babel-unit-test/translations folder.
    setup( function()

        babel = require "babel"
        babel.init( {
            locale = "fr-FR",
            locales_folders = { "babel-unit-tests/translations" }
        } )

        test_date = {

            day   = 17,
            month = 2,
            year  = 1984,
            hour  = 10,
            min   = 42,
            sec   = 3,
            wday   = 5

        }

    end)

    --- Tests about string translations
    describe( "i18n", function()

        it ( "Simple translations", function()
            assert.same( babel.translate( "Hello World" ), "Bonjour Le Monde" )
        end)

        it ( "If no translations are available we display the base string", function()
            assert.same( babel.translate( "Hello Kitty" ), "Hello Kitty" )
        end)

        it ( "Use dynamic values in strings", function()
            assert.same( babel.translate( "Hello %name%", { name = "Kitty" } ), "Hello Kitty" )
        end)

        it ( "_ shortcut is available in clean environement", function()
            assert.same( _, babel.translate )
        end)

    end)

    --- Tests about numbers and dates translations
    describe( "i10n", function()

        describe( "Numbers", function()

            it ( "< 1000 numbers", function()
                assert.same( babel.number( 123.4 ), "123,40" )
            end)

            it ( "> 1000 numbers", function()
                assert.same( babel.number( 12345.6 ), "12 345,60" )
            end)

            it ( "Negative numbers", function()
                assert.same( babel.number( -1234.5 ), "-1 234,50" )
            end)

        end)

        --- Prices are based on numbers so we haven't to test > 1000, < 1000,
        -- < 0, we only need to test the currency symbol
        describe( "Prices", function()

            it ( "Currency symbol is present", function()
                assert.same( babel.price( 5 ), "5,00 €" )
            end)

        end)

        describe( "Date / Time", function()

            it ( "Use predefined date/time formats", function()
                assert.same( babel.dateTime( "long_date_time", test_date ), "vendredi 17 février 1984 10:42:03" )
            end)

            it ( "Use custom format from translation file", function()
                assert.same( babel.dateTime( "busted_test", test_date ), "vendredi 17" )
            end)

            it ( "Use custom format on the fly", function()
                assert.same( babel.dateTime( "%Y", test_date ), "1984" )
            end)

            pending ( "Verify all the date/time 'tags'", function() end)

        end)

    end)

end)
