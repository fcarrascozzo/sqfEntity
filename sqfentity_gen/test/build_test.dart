import 'dart:convert';
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:sqfentity_gen/builder.dart';
import 'package:test/test.dart';

Matcher decodedMatches(Matcher matcher) => _DecodedMatcher(matcher);

class _DecodedMatcher extends Matcher {
  _DecodedMatcher(this._matcher);
  final Matcher _matcher;

  @override
  bool matches(dynamic item, Map<dynamic, dynamic> matchState) {
    final decoded = utf8.decode(item as List<int>);
    return _matcher.matches(decoded, matchState);
  }

  @override
  Description describe(Description description) => description.add('decoded to utf8 then ').addDescriptionOf(_matcher);
}

void main() {
  group('SqfEntityGenerator', () {
    test('generates correct output for a simple model', () async {
      final source = '''
import 'package:sqfentity_gen/sqfentity_gen.dart';
import 'package:sqfentity_gen/sqfentity_base.dart';

@SqfEntityBuilder(myDbModel)
const myDbModel = SqfEntityModel(
  modelName: 'MyDbModel',
  databaseName: 'test.db',
  databaseTables: [
    const SqfEntityTable(
      tableName: 'products',
      primaryKeyName: 'id',
      primaryKeyType: PrimaryKeyType.integer_auto_incremental,
      fields: [
        const SqfEntityField('name', DbType.text),
        const SqfEntityField('price', DbType.real),
      ],
    ),
  ],
);
''';

      // --- MOCK DEFINITIVO ---
      // Os nomes dos campos devem bater EXATAMENTE com a biblioteca real
      final mockLibrary = '''
        class SqfEntityBuilder {
          const SqfEntityBuilder(this.model);
          final dynamic model;
        }

        class SqfEntityModel {
          const SqfEntityModel({
            this.modelName, 
            this.databaseName, 
            this.databaseTables
          });
          final String? modelName;
          final String? databaseName;
          final List? databaseTables;
        }

        class SqfEntityTable {
          const SqfEntityTable({
            this.tableName, 
            this.primaryKeyName, 
            this.primaryKeyType, 
            this.fields
          });
          final String? tableName;
          final String? primaryKeyName;
          final dynamic primaryKeyType;
          final List? fields;
        }

        class SqfEntityField {
          // CORREÇÃO AQUI: 'fieldName' e 'dbType' são os nomes reais usados pela lib
          const SqfEntityField(this.fieldName, this.dbType);
          
          final String fieldName; 
          final dynamic dbType;   
        }

        enum PrimaryKeyType { integer_auto_incremental }
        enum DbType { text, real }
      ''';

      await testBuilder(
        sqfentityBuilder(BuilderOptions.empty),
        {
          'a|lib/model.dart': source,
          'sqfentity_gen|lib/sqfentity_gen.dart': mockLibrary,
          // Adicionamos classes bases vazias para evitar erros no código gerado se ele tentar estender algo
          'sqfentity_gen|lib/sqfentity_base.dart': '''
            class SqfEntityModelProvider {}
            class SqfEntityTableBase {}
            class TableBase {}
          ''',
        },
        outputs: {
          'a|lib/model.sqfentity.g.part': decodedMatches(allOf([
            contains('class MyDbModel extends SqfEntityModelProvider'),
            contains('class TableProduct extends SqfEntityTableBase'),
            contains('class Product extends TableBase'),
            contains('ProductManager get _mnProduct'),
          ]))
        },
      );
    });
  });
}
