
INSERT INTO import_waarnemingen_lang (euring_code, plot_id, territoria, jaar)
SELECT b.euring_code, m.plot_id, b.p_1A, b.jaar FROM import_waarnemingen_breed b
JOIN plotkolom_mapping m ON m.kolomnaam = 'p_1A' WHERE b.p_1A IS NOT NULL;

INSERT INTO import_waarnemingen_lang (euring_code, plot_id, territoria, jaar)
SELECT b.euring_code, m.plot_id, b.p_1B, b.jaar FROM import_waarnemingen_breed b
JOIN plotkolom_mapping m ON m.kolomnaam = 'p_1B' WHERE b.p_1B IS NOT NULL;

INSERT INTO import_waarnemingen_lang (euring_code, plot_id, territoria, jaar)
SELECT b.euring_code, m.plot_id, b.p_2, b.jaar FROM import_waarnemingen_breed b
JOIN plotkolom_mapping m ON m.kolomnaam = 'p_2' WHERE b.p_2 IS NOT NULL;

INSERT INTO import_waarnemingen_lang (euring_code, plot_id, territoria, jaar)
SELECT b.euring_code, m.plot_id, b.p_3, b.jaar FROM import_waarnemingen_breed b
JOIN plotkolom_mapping m ON m.kolomnaam = 'p_3' WHERE b.p_3 IS NOT NULL;

INSERT INTO import_waarnemingen_lang (euring_code, plot_id, territoria, jaar)
SELECT b.euring_code, m.plot_id, b.p_4_5, b.jaar FROM import_waarnemingen_breed b
JOIN plotkolom_mapping m ON m.kolomnaam = 'p_4_5' WHERE b.p_4_5 IS NOT NULL;

INSERT INTO import_waarnemingen_lang (euring_code, plot_id, territoria, jaar)
SELECT b.euring_code, m.plot_id, b.p_6, b.jaar FROM import_waarnemingen_breed b
JOIN plotkolom_mapping m ON m.kolomnaam = 'p_6' WHERE b.p_6 IS NOT NULL;

INSERT INTO import_waarnemingen_lang (euring_code, plot_id, territoria, jaar)
SELECT b.euring_code, m.plot_id, b.p_7, b.jaar FROM import_waarnemingen_breed b
JOIN plotkolom_mapping m ON m.kolomnaam = 'p_7' WHERE b.p_7 IS NOT NULL;

INSERT INTO import_waarnemingen_lang (euring_code, plot_id, territoria, jaar)
SELECT b.euring_code, m.plot_id, b.p_8, b.jaar FROM import_waarnemingen_breed b
JOIN plotkolom_mapping m ON m.kolomnaam = 'p_8' WHERE b.p_8 IS NOT NULL;

-- Blok 2 (10_12_76, 12A, 13, 13S, 14): 5 queries
INSERT INTO import_waarnemingen_lang (euring_code, plot_id, territoria, jaar)
SELECT b.euring_code, m.plot_id, b.p_10_12_76, b.jaar FROM import_waarnemingen_breed b
JOIN plotkolom_mapping m ON m.kolomnaam = 'p_10_12_76' WHERE b.p_10_12_76 IS NOT NULL;

INSERT INTO import_waarnemingen_lang (euring_code, plot_id, territoria, jaar)
SELECT b.euring_code, m.plot_id, b.p_12A, b.jaar FROM import_waarnemingen_breed b
JOIN plotkolom_mapping m ON m.kolomnaam = 'p_12A' WHERE b.p_12A IS NOT NULL;

INSERT INTO import_waarnemingen_lang (euring_code, plot_id, territoria, jaar)
SELECT b.euring_code, m.plot_id, b.p_13, b.jaar FROM import_waarnemingen_breed b
JOIN plotkolom_mapping m ON m.kolomnaam = 'p_13' WHERE b.p_13 IS NOT NULL;

INSERT INTO import_waarnemingen_lang (euring_code, plot_id, territoria, jaar)
SELECT b.euring_code, m.plot_id, b.p_13S, b.jaar FROM import_waarnemingen_breed b
JOIN plotkolom_mapping m ON m.kolomnaam = 'p_13S' WHERE b.p_13S IS NOT NULL;

INSERT INTO import_waarnemingen_lang (euring_code, plot_id, territoria, jaar)
SELECT b.euring_code, m.plot_id, b.p_14, b.jaar FROM import_waarnemingen_breed b
JOIN plotkolom_mapping m ON m.kolomnaam = 'p_14' WHERE b.p_14 IS NOT NULL;

-- Blok 3 (15, 16+, 16S, 17A, 17B): 5 queries
INSERT INTO import_waarnemingen_lang (euring_code, plot_id, territoria, jaar)
SELECT b.euring_code, m.plot_id, b.p_15, b.jaar FROM import_waarnemingen_breed b
JOIN plotkolom_mapping m ON m.kolomnaam = 'p_15' WHERE b.p_15 IS NOT NULL;

INSERT INTO import_waarnemingen_lang (euring_code, plot_id, territoria, jaar)
SELECT b.euring_code, m.plot_id, b.p_16plus, b.jaar FROM import_waarnemingen_breed b
JOIN plotkolom_mapping m ON m.kolomnaam = 'p_16plus' WHERE b.p_16plus IS NOT NULL;

INSERT INTO import_waarnemingen_lang (euring_code, plot_id, territoria, jaar)
SELECT b.euring_code, m.plot_id, b.p_16S, b.jaar FROM import_waarnemingen_breed b
JOIN plotkolom_mapping m ON m.kolomnaam = 'p_16S' WHERE b.p_16S IS NOT NULL;

INSERT INTO import_waarnemingen_lang (euring_code, plot_id, territoria, jaar)
SELECT b.euring_code, m.plot_id, b.p_17A, b.jaar FROM import_waarnemingen_breed b
JOIN plotkolom_mapping m ON m.kolomnaam = 'p_17A' WHERE b.p_17A IS NOT NULL;

INSERT INTO import_waarnemingen_lang (euring_code, plot_id, territoria, jaar)
SELECT b.euring_code, m.plot_id, b.p_17B, b.jaar FROM import_waarnemingen_breed b
JOIN plotkolom_mapping m ON m.kolomnaam = 'p_17B' WHERE b.p_17B IS NOT NULL;

INSERT INTO import_waarnemingen_lang (euring_code, plot_id, territoria, jaar)
SELECT b.euring_code, m.plot_id, b.p_31, b.jaar FROM import_waarnemingen_breed b
JOIN plotkolom_mapping m ON m.kolomnaam = 'p_31' WHERE b.p_31 IS NOT NULL;

INSERT INTO import_waarnemingen_lang (euring_code, plot_id, territoria, jaar)
SELECT b.euring_code, m.plot_id, b.p_32, b.jaar FROM import_waarnemingen_breed b
JOIN plotkolom_mapping m ON m.kolomnaam = 'p_32' WHERE b.p_32 IS NOT NULL;

INSERT INTO import_waarnemingen_lang (euring_code, plot_id, territoria, jaar)
SELECT b.euring_code, m.plot_id, b.p_33, b.jaar FROM import_waarnemingen_breed b
JOIN plotkolom_mapping m ON m.kolomnaam = 'p_33' WHERE b.p_33 IS NOT NULL;

INSERT INTO import_waarnemingen_lang (euring_code, plot_id, territoria, jaar)
SELECT b.euring_code, m.plot_id, b.p_34, b.jaar FROM import_waarnemingen_breed b
JOIN plotkolom_mapping m ON m.kolomnaam = 'p_34' WHERE b.p_34 IS NOT NULL;

INSERT INTO import_waarnemingen_lang (euring_code, plot_id, territoria, jaar)
SELECT b.euring_code, m.plot_id, b.p_35, b.jaar FROM import_waarnemingen_breed b
JOIN plotkolom_mapping m ON m.kolomnaam = 'p_35' WHERE b.p_35 IS NOT NULL;

INSERT INTO import_waarnemingen_lang (euring_code, plot_id, territoria, jaar)
SELECT b.euring_code, m.plot_id, b.p_36, b.jaar FROM import_waarnemingen_breed b
JOIN plotkolom_mapping m ON m.kolomnaam = 'p_36' WHERE b.p_36 IS NOT NULL;

-- Blok 5 (41-46): 5 queries
INSERT INTO import_waarnemingen_lang (euring_code, plot_id, territoria, jaar)
SELECT b.euring_code, m.plot_id, b.p_41, b.jaar FROM import_waarnemingen_breed b
JOIN plotkolom_mapping m ON m.kolomnaam = 'p_41' WHERE b.p_41 IS NOT NULL;

INSERT INTO import_waarnemingen_lang (euring_code, plot_id, territoria, jaar)
SELECT b.euring_code, m.plot_id, b.p_42, b.jaar FROM import_waarnemingen_breed b
JOIN plotkolom_mapping m ON m.kolomnaam = 'p_42' WHERE b.p_42 IS NOT NULL;

INSERT INTO import_waarnemingen_lang (euring_code, plot_id, territoria, jaar)
SELECT b.euring_code, m.plot_id, b.p_43, b.jaar FROM import_waarnemingen_breed b
JOIN plotkolom_mapping m ON m.kolomnaam = 'p_43' WHERE b.p_43 IS NOT NULL;

INSERT INTO import_waarnemingen_lang (euring_code, plot_id, territoria, jaar)
SELECT b.euring_code, m.plot_id, b.p_45, b.jaar FROM import_waarnemingen_breed b
JOIN plotkolom_mapping m ON m.kolomnaam = 'p_45' WHERE b.p_45 IS NOT NULL;

INSERT INTO import_waarnemingen_lang (euring_code, plot_id, territoria, jaar)
SELECT b.euring_code, m.plot_id, b.p_46, b.jaar FROM import_waarnemingen_breed b
JOIN plotkolom_mapping m ON m.kolomnaam = 'p_46' WHERE b.p_46 IS NOT NULL;

INSERT INTO import_waarnemingen_lang (euring_code, plot_id, territoria, jaar)
SELECT b.euring_code, m.plot_id, b.p_51, b.jaar FROM import_waarnemingen_breed b
JOIN plotkolom_mapping m ON m.kolomnaam = 'p_51' WHERE b.p_51 IS NOT NULL;

INSERT INTO import_waarnemingen_lang (euring_code, plot_id, territoria, jaar)
SELECT b.euring_code, m.plot_id, b.p_52, b.jaar FROM import_waarnemingen_breed b
JOIN plotkolom_mapping m ON m.kolomnaam = 'p_52' WHERE b.p_52 IS NOT NULL;

INSERT INTO import_waarnemingen_lang (euring_code, plot_id, territoria, jaar)
SELECT b.euring_code, m.plot_id, b.p_53, b.jaar FROM import_waarnemingen_breed b
JOIN plotkolom_mapping m ON m.kolomnaam = 'p_53' WHERE b.p_53 IS NOT NULL;

INSERT INTO import_waarnemingen_lang (euring_code, plot_id, territoria, jaar)
SELECT b.euring_code, m.plot_id, b.p_54A, b.jaar FROM import_waarnemingen_breed b
JOIN plotkolom_mapping m ON m.kolomnaam = 'p_54A' WHERE b.p_54A IS NOT NULL;

INSERT INTO import_waarnemingen_lang (euring_code, plot_id, territoria, jaar)
SELECT b.euring_code, m.plot_id, b.p_54B, b.jaar FROM import_waarnemingen_breed b
JOIN plotkolom_mapping m ON m.kolomnaam = 'p_54B' WHERE b.p_54B IS NOT NULL;

INSERT INTO import_waarnemingen_lang (euring_code, plot_id, territoria, jaar)
SELECT b.euring_code, m.plot_id, b.p_55, b.jaar FROM import_waarnemingen_breed b
JOIN plotkolom_mapping m ON m.kolomnaam = 'p_55' WHERE b.p_55 IS NOT NULL;

INSERT INTO import_waarnemingen_lang (euring_code, plot_id, territoria, jaar)
SELECT b.euring_code, m.plot_id, b.p_61, b.jaar FROM import_waarnemingen_breed b
JOIN plotkolom_mapping m ON m.kolomnaam = 'p_61' WHERE b.p_61 IS NOT NULL;

INSERT INTO import_waarnemingen_lang (euring_code, plot_id, territoria, jaar)
SELECT b.euring_code, m.plot_id, b.p_62, b.jaar FROM import_waarnemingen_breed b
JOIN plotkolom_mapping m ON m.kolomnaam = 'p_62' WHERE b.p_62 IS NOT NULL;

INSERT INTO import_waarnemingen_lang (euring_code, plot_id, territoria, jaar)
SELECT b.euring_code, m.plot_id, b.p_63, b.jaar FROM import_waarnemingen_breed b
JOIN plotkolom_mapping m ON m.kolomnaam = 'p_63' WHERE b.p_63 IS NOT NULL;

INSERT INTO import_waarnemingen_lang (euring_code, plot_id, territoria, jaar)
SELECT b.euring_code, m.plot_id, b.p_64, b.jaar FROM import_waarnemingen_breed b
JOIN plotkolom_mapping m ON m.kolomnaam = 'p_64' WHERE b.p_64 IS NOT NULL;

INSERT INTO import_waarnemingen_lang (euring_code, plot_id, territoria, jaar)
SELECT b.euring_code, m.plot_id, b.p_65, b.jaar FROM import_waarnemingen_breed b
JOIN plotkolom_mapping m ON m.kolomnaam = 'p_65' WHERE b.p_65 IS NOT NULL;

INSERT INTO import_waarnemingen_lang (euring_code, plot_id, territoria, jaar)
SELECT b.euring_code, m.plot_id, b.p_66, b.jaar FROM import_waarnemingen_breed b
JOIN plotkolom_mapping m ON m.kolomnaam = 'p_66' WHERE b.p_66 IS NOT NULL;

INSERT INTO import_waarnemingen_lang (euring_code, plot_id, territoria, jaar)
SELECT b.euring_code, m.plot_id, b.p_71, b.jaar FROM import_waarnemingen_breed b
JOIN plotkolom_mapping m ON m.kolomnaam = 'p_71' WHERE b.p_71 IS NOT NULL;

INSERT INTO import_waarnemingen_lang (euring_code, plot_id, territoria, jaar)
SELECT b.euring_code, m.plot_id, b.p_72, b.jaar FROM import_waarnemingen_breed b
JOIN plotkolom_mapping m ON m.kolomnaam = 'p_72' WHERE b.p_72 IS NOT NULL;

INSERT INTO import_waarnemingen_lang (euring_code, plot_id, territoria, jaar)
SELECT b.euring_code, m.plot_id, b.p_73, b.jaar FROM import_waarnemingen_breed b
JOIN plotkolom_mapping m ON m.kolomnaam = 'p_73' WHERE b.p_73 IS NOT NULL;

INSERT INTO import_waarnemingen_lang (euring_code, plot_id, territoria, jaar)
SELECT b.euring_code, m.plot_id, b.p_74, b.jaar FROM import_waarnemingen_breed b
JOIN plotkolom_mapping m ON m.kolomnaam = 'p_74' WHERE b.p_74 IS NOT NULL;

INSERT INTO import_waarnemingen_lang (euring_code, plot_id, territoria, jaar)
SELECT b.euring_code, m.plot_id, b.p_75, b.jaar FROM import_waarnemingen_breed b
JOIN plotkolom_mapping m ON m.kolomnaam = 'p_75' WHERE b.p_75 IS NOT NULL;

INSERT INTO import_waarnemingen_lang (euring_code, plot_id, territoria, jaar)
SELECT b.euring_code, m.plot_id, b.p_75A, b.jaar FROM import_waarnemingen_breed b
JOIN plotkolom_mapping m ON m.kolomnaam = 'p_75A' WHERE b.p_75A IS NOT NULL;

INSERT INTO import_waarnemingen_lang (euring_code, plot_id, territoria, jaar)
SELECT b.euring_code, m.plot_id, b.p_77, b.jaar FROM import_waarnemingen_breed b
JOIN plotkolom_mapping m ON m.kolomnaam = 'p_77' WHERE b.p_77 IS NOT NULL;

INSERT INTO import_waarnemingen_lang (euring_code, plot_id, territoria, jaar)
SELECT b.euring_code, m.plot_id, b.p_78_79, b.jaar FROM import_waarnemingen_breed b
JOIN plotkolom_mapping m ON m.kolomnaam = 'p_78_79' WHERE b.p_78_79 IS NOT NULL;

INSERT INTO import_waarnemingen_lang (euring_code, plot_id, territoria, jaar)
SELECT b.euring_code, m.plot_id, b.p_83, b.jaar FROM import_waarnemingen_breed b
JOIN plotkolom_mapping m ON m.kolomnaam = 'p_83' WHERE b.p_83 IS NOT NULL;

INSERT INTO import_waarnemingen_lang (euring_code, plot_id, territoria, jaar)
SELECT b.euring_code, m.plot_id, b.p_84, b.jaar FROM import_waarnemingen_breed b
JOIN plotkolom_mapping m ON m.kolomnaam = 'p_84' WHERE b.p_84 IS NOT NULL;

INSERT INTO import_waarnemingen_lang (euring_code, plot_id, territoria, jaar)
SELECT b.euring_code, m.plot_id, b.p_85, b.jaar FROM import_waarnemingen_breed b
JOIN plotkolom_mapping m ON m.kolomnaam = 'p_85' WHERE b.p_85 IS NOT NULL;

INSERT INTO import_waarnemingen_lang (euring_code, plot_id, territoria, jaar)
SELECT b.euring_code, m.plot_id, b.p_91, b.jaar FROM import_waarnemingen_breed b
JOIN plotkolom_mapping m ON m.kolomnaam = 'p_91' WHERE b.p_91 IS NOT NULL;

INSERT INTO import_waarnemingen_lang (euring_code, plot_id, territoria, jaar)
SELECT b.euring_code, m.plot_id, b.p_105, b.jaar FROM import_waarnemingen_breed b
JOIN plotkolom_mapping m ON m.kolomnaam = 'p_105' WHERE b.p_105 IS NOT NULL;