interface InitItem<t> {

    command void init (t *Item);

    command void free (t *Item);

}
