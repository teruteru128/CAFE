/+ ------------------------------------------------------------ +
 + Author : aoitofu <aoitofu@dr.com>                            +
 + This is part of CAFE ( https://github.com/aoitofu/CAFE ).    +
 + ------------------------------------------------------------ +
 + Please see /LICENSE.                                         +
 + ------------------------------------------------------------ +/
module cafe.gui.controls.timeline.Line;
import cafe.gui.utils.Font,
       cafe.gui.utils.Rect,
       cafe.gui.controls.timeline.Cache,
       cafe.project.timeline.PlaceableObject,
       cafe.project.timeline.property.Property,
       cafe.project.timeline.effect.Effect;
import std.algorithm,
       std.conv,
       std.format;
import dlangui;

abstract class Line
{
    enum HeaderStyle = "TIMELINE_LINE_HEADER";

    protected:
        Cache cache;
        string line_name;

    public:
        @property name () { return line_name; }

        @property float heightMag    () { return 1.0; }
        @property bool  needBorder () { return true; }

        @property int layerIndex () { return -1; }

        this ( Cache c, string n )
        {
            cache = c;
            line_name = n;
        }

        void drawHeader ( DrawBuf b, Rect r )
        {
            auto style = currentTheme.get( HeaderStyle );
            if ( style.backgroundDrawable )
                style.backgroundDrawable.drawTo( b, r );

            auto x = r.left + (r.right -r.left)/2;
            auto y = r.top  + (r.bottom-r.top )/2;
            style.font.drawCenteredText( b, x, y, name, style.textColor );
        }

        void drawContent ( DrawBuf, Rect );

        bool onHeaderLeftClicked ()
        {
            return false;
        }

        bool onContentLeftClicked ( uint )
        {
            return false;
        }
}

class LayerLine : Line
{
    enum TitleFormat = "Layer %d";
    enum ContentStyle = "TIMELINE_LAYER_LINE";

    private:
        int lindex;
        PlaceableObject[] objs;

    public:
        override @property int layerIndex () { return lindex; }

        this ( Cache c, uint l, PlaceableObject[] o )
        {
            super( c, TitleFormat.format(l) );
            lindex = l;
            objs = o;
        }

        override void drawContent ( DrawBuf b, Rect r )
        {
            auto style = currentTheme.get( ContentStyle );
            if ( style.backgroundDrawable )
                style.backgroundDrawable.drawTo( b, r );

            auto st = cache.timeline.leftFrame;
            auto ed = cache.timeline.rightFrame;
            auto ppf = cache.pxPerFrame;
            auto pad = style.padding;
            auto sel = cache.timeline.selecting;

            foreach ( o; objs ) {
                auto ost = o.place.frame.start.value;
                auto oed = o.place.frame.end.value;

                if ( oed > st && ost < ed ) {
                    auto r_ost = ost.to!int - st.to!int;
                    auto r_oed = oed.to!int - st.to!int;

                    auto obj_r = Rect( r.left + (r_ost*ppf).to!int, r.top + pad.top,
                            r.left + (r_oed*ppf).to!int, r.bottom - pad.bottom );
                    b.clipRect = obj_r.shrinkRect( b.clipRect );
                    o.draw( b, obj_r );
                    b.drawFrame( obj_r, style.textColor,
                            o is sel ? Rect(2,2,2,2) : Rect(1,1,1,1) );
                }
            }
        }
}

class PropertyLine : Line
{
    enum ContentStyle = "TIMELINE_PROPERTY_LINE";
    enum MPDrawable = "tl_propline_mp";
    enum MPSize = 12;

    private:
        Property property;

    public:
        override @property float heightMag ()
        {
            return 0.7;
        }

        override @property bool needBorder () { return false; }

        this ( Cache c, string n, Property p )
        {
            super( c, n );
            property = p;
        }

        override void drawContent ( DrawBuf b, Rect r )
        {
            auto style = currentTheme.get( ContentStyle );
            if ( style.backgroundDrawable )
                style.backgroundDrawable.drawTo( b, r );

            auto st     = cache.timeline.leftFrame;
            auto ppf    = cache.pxPerFrame;
            auto parent = cache.timeline.selecting.place.frame.start.value.to!int;

            auto drawMiddlePoint ( uint f )
            {
                enum sz = MPSize/2;
                auto rf = f.to!int + parent - st.to!int;
                auto x  = r.left + (rf * ppf).to!int;
                auto y  = r.top + (r.bottom-r.top)/2;
                auto dr = Rect( x-sz, y-sz, x+sz, y+sz );
                style.customDrawable( MPDrawable ).drawTo( b, dr );
            }
            property.middlePoints.each!
                ( x => drawMiddlePoint( x.frame.start.value ) );
            drawMiddlePoint( property.frame.value );
        }
}

class EffectLine : Line
{
    enum ContentStyle = "TIMELINE_EFFECT_LINE";

    private:
        Effect effect;

    public:
        override @property float heightMag ()
        {
            return 0.7;
        }
        override @property bool needBorder () { return false; }

        this ( Cache c, Effect e )
        {
            super( c, e.name );
            effect = e;
        }

        override void drawContent ( DrawBuf b, Rect r )
        {
            auto style = currentTheme.get( ContentStyle );
            if ( style.backgroundDrawable )
                style.backgroundDrawable.drawTo( b, r );

            auto st  = cache.timeline.leftFrame;
            auto ed  = cache.timeline.rightFrame;
            auto est = cache.timeline.selecting.place.frame.start.value;
            auto eed = cache.timeline.selecting.place.frame.end.value;
            auto ppf = cache.pxPerFrame;
            auto pad = style.padding;

            if ( eed > st && est < ed ) {
                auto r_est = est.to!int - st.to!int;
                auto r_eed = eed.to!int - st.to!int;

                auto r_ef = Rect( r.left + (r_est*ppf).to!int, r.top + pad.top,
                       r.left + (r_eed*ppf).to!int, r.bottom - pad.bottom );
                b.clipRect = r_ef.shrinkRect( b.clipRect );
                effect.draw( b, r_ef );
                b.drawFrame( r_ef, style.textColor, Rect(1,1,1,1) );

                b.resetClipping;
            }
        }

        override bool onHeaderLeftClicked ()
        {
            effect.propertiesOpened = !effect.propertiesOpened;
            cache.updateLinesCache;
            return true;
        }

        override bool onContentLeftClicked ( uint f )
        {
            auto est = cache.timeline.selecting.place.frame.start.value;
            auto eed = cache.timeline.selecting.place.frame.end.value;
            return (f >= est && f < eed) ? onHeaderLeftClicked : false;
        }
}
