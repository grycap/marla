<template>

  <v-form v-model="valid">
    <v-container>
      <v-toolbar dark color="primary">
          <v-toolbar-title class="white--text">APP WEB MARLA</v-toolbar-title>
      </v-toolbar>
      <v-layout>
        <v-flex
          xs12
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
            :counter="10"
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
            :counter="10"
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
            :counter="10"
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
            :counter="10"
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
            :counter="10"
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
          <v-text-field
            v-model="Region"
            :rules="nameRules"
            :counter="10"
            label="Region"
            required
          ></v-text-field>
        </v-flex>

        <v-flex
          xs12
          md4
        >
          <v-text-field
            v-model="BucketIn"
            :rules="nameRules"
            :counter="10"
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
            :counter="10"
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
            :counter="10"
            label="RoleARN"
            required
          ></v-text-field>
        </v-flex>

        <v-flex
          xs12
          md4
        >
          <v-text-field
            v-model="MinBlockSize"
            :rules="nameRules"
            :counter="10"
            label="MinBlockSize"
            required
          ></v-text-field>
        </v-flex>

        <v-flex
          xs12
          md4
        >
          <v-text-field
            v-model="MaxBlockSize"
            :rules="nameRules"
            :counter="10"
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
            :counter="10"
            label="KMSKeyARN"
            required
          ></v-text-field>
        </v-flex>

        <v-flex
          xs12
          md4
        >
          <v-text-field
            v-model="MapperMemory"
            :rules="nameRules"
            :counter="10"
            label="MapperMemory"
            required
          ></v-text-field>
        </v-flex>

        <v-flex
          xs12
          md4
        >
          <v-text-field
            v-model="ReducerMemory"
            :rules="nameRules"
            :counter="10"
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
            v-model="TimeOut"
            :rules="nameRules"
            :counter="10"
            label="TimeOut"
            required
          ></v-text-field>
        </v-flex>

        <v-flex
          xs12
          md4
        >
          <v-text-field
            v-model="ReducersNumber"
            :rules="nameRules"
            :counter="10"
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
      nameRules: [
        v => !!v || 'Name is required',
        v => (v && v.length <= 10) || 'Name must be less than 10 characters'
      ],
      email: '',
      emailRules: [
        v => !!v || 'E-mail is required',
        v => /.+@.+/.test(v) || 'E-mail must be valid'
      ],
      select: null,
      items: [
        'Item 1',
        'Item 2',
        'Item 3',
        'Item 4'
      ],
      checkbox: false
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
