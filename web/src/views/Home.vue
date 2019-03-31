<template>

  <v-form v-model="valid">
    <v-container>
      <v-toolbar dark color="primary">
          <v-toolbar-title class="white--text">APP WEB MARLA</v-toolbar-title>
      </v-toolbar>
      <v-layout>
        <v-flex
          xs12g
          md4
        >
          <h2 class="grey--text">Step 1. Credentials</h2>
        </v-flex>
      </v-layout>
      <v-layout>
        <v-flex
          xs12
          md4
        >
          <v-text-field
            v-model="AK"
            :rules="nameRules"
            label="AK"
            required
          ></v-text-field>
        </v-flex>

        <v-flex
          xs12
          md4
        >
          <v-text-field
            v-model="SK"
            :rules="nameRules"
            label="SK"
            required
          ></v-text-field>
        </v-flex>


      </v-layout>

      <v-layout>
        <v-flex
          xs12
          md4
        >
          <h2 class="grey--text">Step 2. Config parametres</h2>
        </v-flex>
      </v-layout>
      <v-layout>
        <v-flex
          xs12
          md4
        >
          <v-text-field
            v-model="ClusterName"
            :rules="nameRules"
            label="ClusterName"
            required
          ></v-text-field>
        </v-flex>

        <v-flex
          xs12
          md4
        >
          <v-text-field
            v-model="FunctionsDir"
            :rules="nameRules"
            label="FunctionsDir"
            required
          ></v-text-field>
        </v-flex>

        <v-flex
          xs12
          md4
        >
          <v-text-field
            v-model="FunctionsFile"
            :rules="nameRules"
            label="FunctionsFile"
            required
          ></v-text-field>
        </v-flex>
      </v-layout>

      <v-layout>
        <v-flex
          xs12
          md4
        >
          <v-select
            v-model="select"
            :items="itemsRegion"
            :rules="nameRules"
            label="Region"
            required
          ></v-select>
        </v-flex>

        <v-flex
          xs12
          md4
        >
          <v-text-field
            v-model="BucketIn"
            :rules="nameRules"
            label="BucketIn"
            required
          ></v-text-field>
        </v-flex>

        <v-flex
          xs12
          md4
        >
          <v-text-field
            v-model="BucketOut"
            :rules="nameRules"
            label="BucketOut"
            required
          ></v-text-field>
        </v-flex>
      </v-layout>

      <v-layout>
        <v-flex
          xs12
          md4
        >
          <v-text-field
            v-model="RoleARN"
            :rules="nameRules"
            label="RoleARN"
            required
          ></v-text-field>
        </v-flex>

        <v-flex
          xs12
          md4
        >
          <v-text-field
            v-model="modelMinBlockSize"
            :rules="nameRules"
            label="MinBlockSize"
            required
          ></v-text-field>
        </v-flex>

        <v-flex
          xs12
          md4
        >
          <v-text-field
            v-model="modelMaxBlockSize"
            :rules="nameRules"
            label="MaxBlockSize"
            required
          ></v-text-field>
        </v-flex>
      </v-layout>

      <v-layout>
        <v-flex
          xs12
          md4
        >
          <v-text-field
            v-model="KMSKeyARN"
            :rules="nameRules"
            label="KMSKeyARN"
            required
          ></v-text-field>
        </v-flex>

        <v-flex
          xs12
          md4
        >
          <v-text-field
            v-model="modelMapperMemory"
            :rules="nameRules"
            label="MapperMemory"
            required
          ></v-text-field>
        </v-flex>

        <v-flex
          xs12
          md4
        >
          <v-text-field
            v-model="modelReducerMemory"
            :rules="nameRules"
            label="ReducerMemory"
            required
          ></v-text-field>
        </v-flex>
      </v-layout>


      <v-layout>
        <v-flex
          xs12
          md4
        >
          <v-text-field
            v-model="modelTimeOut"
            :rules="nameRules"
            label="TimeOut"
            required
          ></v-text-field>
        </v-flex>

        <v-flex
          xs12
          md4
        >
          <v-text-field
            v-model="modelReducersNumber"
            :rules="nameRules"
            label="ReducersNumber"
            required
          ></v-text-field>
        </v-flex>

      </v-layout>

      <v-layout>
        <v-flex
          xs12
          md4
        >
          <h2 class="grey--text">Step 3. Upload Dataset</h2>
        </v-flex>
      </v-layout>

      <v-layout>
        <v-flex
          xs12
          md4
        >
          <v-btn
            :loading="loading3"
            :disabled="loading3"
            color="blue-grey"
            class="white--text"
            @click="loader = 'loading3'"
          >
            Upload
            <v-icon right dark>cloud_upload</v-icon>
          </v-btn>
        </v-flex>
      </v-layout>

      <v-layout>
        <v-btn
         :disabled="!valid"
         color="success"
         @click="validate"
       >
         START PROCESS
       </v-btn>
      </v-layout>

      <v-layout>
        <v-flex
          xs12
          md4
        >
          <h2 class="grey--text">Results</h2>
        </v-flex>
      </v-layout>

    </v-container>
  </v-form>


</template>

<script>
  export default {
    data: () => ({
      valid: true,
      name: '',
      modelMaxBlockSize:'0',
      modelMinBlockSize:'1024',
      modelMapperMemory:'1536',
      modelReducerMemory:'1536',
      modelTimeOut:'180',
      modelReducersNumber:'10',


      nameRules: [
        v => !!v || 'Required data',
        //v => (v && v.length <= 10) || 'Name must be less than 10 characters'
      ],
      select: null,
      itemsRegion: [
      'us-east-1',
      'us-east-2',
      'us-west-1',
      'us-west-2',
      'ca-central-1',
      'eu-central-1',
      'eu-west-1',
      'eu-west-2',
      'eu-west-3',
      'eu-north-1',
      'ap-northeast-1',
      'ap-northeast-2',
      'ap-northeast-3',
      'ap-southeast-1',
      'ap-southeast-2',
      'ap-south-1',
      'sa-east-1'
    ],

    }),

    methods: {
      validate () {
        if (this.$refs.form.validate()) {
          this.snackbar = true
        }
      },
      reset () {
        this.$refs.form.reset()
      },
      resetValidation () {
        this.$refs.form.resetValidation()
      }
    }
  }
</script>
