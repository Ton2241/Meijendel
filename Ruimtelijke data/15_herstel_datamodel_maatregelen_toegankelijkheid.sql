SELECT
  (SELECT COUNT(*) FROM maatregelen) AS n_maatregelen,
  (SELECT COUNT(*) FROM plot_jaar_maatregel) AS n_plot_jaar_maatregel,
  (SELECT COUNT(*) FROM plot_jaar_toegankelijkheid_deel) AS n_plot_jaar_toegankelijkheid_deel;
