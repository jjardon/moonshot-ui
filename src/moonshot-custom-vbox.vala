using Gtk;

class CustomVBox : VBox
{
    public IdCardWidget current_idcard { get; set; default = null; }

    public CustomVBox (bool homogeneous, int spacing)
    {
        this.set_homogeneous (homogeneous);
        this.set_spacing (spacing);
    }

    public void receive_expanded_event (IdCardWidget id_card_widget)
    {
        var list = this.get_children ();
        foreach (Widget id_card in list)
        {
            if (id_card != id_card_widget)
                ((IdCardWidget) id_card).collapse ();
        }
    }
}